#!/usr/bin/env bash
# Usado pelo GitHub Actions: confere se resultados.csv saiu completo e coerente.
# Uso: bash .github/confere.sh <resultados.csv> <MB>
set -e
csv=$1; mb=$2
tr -d '\r' < "$csv" > /tmp/r.csv
cat /tmp/r.csv
linhas=$(wc -l < /tmp/r.csv | tr -d ' ')
[ "$linhas" -eq 7 ] || { echo "ERRO: esperava 7 linhas, veio $linhas"; exit 1; }
esperado=$((mb * 1048576))
sys1=$(awk -F, 'NR==2{print $2}' /tmp/r.csv)
[ "$sys1" = "$esperado" ] || { echo "ERRO: buffer de 1 B deveria fazer $esperado syscalls, fez $sys1"; exit 1; }
awk -F, 'NR==2{v1=$4} NR==6{v64=$4} END{ if (v64 < 20*v1) { print "ERRO: 64 KB deveria ser muito mais rapido que 1 B (" v1 " vs " v64 " MB/s)"; exit 1 } else print "OK: 64 KB foi " int(v64/v1) "x mais rapido que 1 B" }' /tmp/r.csv
