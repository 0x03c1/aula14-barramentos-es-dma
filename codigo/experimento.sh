#!/usr/bin/env bash
# experimento.sh — roda a bateria completa e gera resultados.csv
# Funciona em Linux, macOS e no Git Bash/WSL do Windows.
#
# Uso:
#   ./experimento.sh                 arquivo de 256 MB, limpa o cache antes de cada medição (pede sudo)
#   ./experimento.sh 64              arquivo de 64 MB (o buffer de 1 B termina bem mais rápido)
#   SEM_LIMPAR=1 ./experimento.sh    não limpa o cache (não precisa de sudo; mede com cache quente)
set -e
cd "$(dirname "$0")"

MB=${1:-256}
case "$(uname -s)" in
  Linux*)               SO=linux ;;
  Darwin*)              SO=macos ;;
  MINGW*|MSYS*|CYGWIN*) SO=gitbash ;;
  *)                    SO=outro ;;
esac

if [ "$SO" = gitbash ] || [ "$SO" = outro ]; then
  echo "Aviso: neste ambiente não há comando para limpar o cache do SO."
  echo "       A medição será com cache quente (a conclusão sobre o custo da syscall não muda)."
  SEM_LIMPAR=1
fi

limpar_cache() {
  [ -n "$SEM_LIMPAR" ] && return 0
  sync
  case "$SO" in
    linux) sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' ;;   # esvazia o cache de páginas
    macos) sudo purge ;;                                       # equivalente no macOS
  esac
}

echo "Sistema: $SO | arquivo: ${MB} MB | limpar cache: $([ -n "$SEM_LIMPAR" ] && echo não || echo sim)"
[ -n "$SEM_LIMPAR" ] || sudo -v          # pede a senha uma vez só, no começo

ARQ="dados_${MB}MB.bin"
if [ ! -f "$ARQ" ]; then
  echo "Criando $ARQ ..."
  dd if=/dev/urandom of="$ARQ" bs=1048576 count="$MB" 2>/dev/null
fi

CC=""
for c in gcc clang cc; do command -v "$c" >/dev/null 2>&1 && { CC=$c; break; }; done
if [ -z "$CC" ]; then
  echo "Nenhum compilador C encontrado. Instale: Linux 'sudo apt install build-essential' | macOS 'xcode-select --install'"
  exit 1
fi
$CC -O2 io.c -o io
$CC -O2 io_fread.c -o io_fread

echo "buffer_B,syscalls,tempo_s,MBps,us_por_read" > resultados.csv
for b in 1 16 256 4096 65536 1048576; do
  limpar_cache
  linha=$(./io "$ARQ" "$b")
  echo "$linha"
  echo "$linha" | awk -F'|' '{for(i=1;i<=5;i++){gsub(/[^0-9.]/,"",$i)} print $1","$2","$3","$4","$5}' >> resultados.csv
done

echo
echo "== fread com 1 byte =="
limpar_cache
./io_fread "$ARQ"

if [ "$SO" = linux ] && command -v strace >/dev/null 2>&1; then
  echo
  echo "== read() reais feitas pelo fread (strace) =="
  strace -c -e trace=read ./io_fread "$ARQ" 2>&1 >/dev/null | grep -E "calls|read" || true
else
  echo
  echo "(strace só existe no Linux. Aqui, use a coluna 'syscalls' do io.c para contar as chamadas.)"
fi

echo
echo "Pronto! Abra resultados.csv numa planilha e plote MB/s x buffer (eixo X em escala log)."
