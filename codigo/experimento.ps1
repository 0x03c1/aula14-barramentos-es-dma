# experimento.ps1 — roda a bateria completa no Windows (PowerShell 5.1 ou 7+) e gera resultados.csv
#
# Uso (no PowerShell, dentro da pasta codigo):
#   powershell -ExecutionPolicy Bypass -File .\experimento.ps1            arquivo de 256 MB
#   powershell -ExecutionPolicy Bypass -File .\experimento.ps1 -MB 64     arquivo de 64 MB (mais rápido)
#   ... -Compilador cl                                                   força o compilador (auto, gcc, clang, cl)
#
# Cache do SO: o Windows não tem um comando nativo para esvaziar o cache de arquivos.
# Se o RAMMap (Sysinternals) estiver na pasta ou no PATH e o PowerShell estiver como
# Administrador, o script usa "RAMMap -Et" antes de cada medição. Sem isso, mede com
# cache quente: a diferença entre 1 B e 64 KB (custo da syscall) continua aparecendo.
param(
  [int]$MB = 256,
  [ValidateSet('auto','gcc','clang','cl')][string]$Compilador = 'auto',
  [switch]$SemLimpar
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Encontrar([string[]]$nomes) {
  foreach ($n in $nomes) {
    $local = Join-Path $PSScriptRoot $n
    if (Test-Path -LiteralPath $local) { return $local }
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  return $null
}

# ---------- compilador ----------
if ($Compilador -eq 'auto') { $ordem = @('gcc','clang','cl') } else { $ordem = @($Compilador) }
$cc = $null; $tipo = $null
foreach ($n in $ordem) {
  $c = Get-Command $n -ErrorAction SilentlyContinue
  if ($c) { $cc = $c.Source; $tipo = $n; break }
}
if (-not $cc) {
  Write-Host "Nenhum compilador C encontrado (gcc, clang ou cl)." -ForegroundColor Red
  Write-Host "Opcoes: 1) use o WSL2 e rode ./experimento.sh"
  Write-Host "        2) instale o gcc (MSYS2 ou WinLibs) e reabra o PowerShell"
  Write-Host "        3) abra o 'Developer PowerShell for VS' (Visual Studio) para ter o cl"
  exit 1
}
Write-Host "Compilador: $tipo ($cc)"
if ($tipo -eq 'cl') {
  & $cc /nologo /O2 io.c /Feio.exe | Out-Null;             if ($LASTEXITCODE -ne 0) { throw "falha ao compilar io.c" }
  & $cc /nologo /O2 io_fread.c /Feio_fread.exe | Out-Null; if ($LASTEXITCODE -ne 0) { throw "falha ao compilar io_fread.c" }
} else {
  & $cc -O2 io.c -o io.exe;             if ($LASTEXITCODE -ne 0) { throw "falha ao compilar io.c" }
  & $cc -O2 io_fread.c -o io_fread.exe; if ($LASTEXITCODE -ne 0) { throw "falha ao compilar io_fread.c" }
}

# ---------- limpeza de cache (opcional) ----------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$rammap = $null
if (-not $SemLimpar) { $rammap = Encontrar @('RAMMap64.exe','RAMMap.exe') }
if ($rammap -and -not $admin) {
  Write-Host "RAMMap encontrado, mas o PowerShell nao esta como Administrador: medindo com cache quente." -ForegroundColor Yellow
  $rammap = $null
}
if ($rammap) { Write-Host "Limpar cache: sim (RAMMap -Et)" } else { Write-Host "Limpar cache: nao (cache quente)" }

function Limpar-Cache {
  if ($script:rammap) {
    Start-Process -FilePath $script:rammap -ArgumentList '-accepteula','-Et' -Wait -WindowStyle Hidden
  }
}

# ---------- arquivo de teste ----------
$arq = "dados_${MB}MB.bin"
if (-not (Test-Path -LiteralPath $arq)) {
  Write-Host "Criando $arq ..."
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bloco = New-Object byte[] 1048576
  $fs = [System.IO.File]::Create((Join-Path $PSScriptRoot $arq))
  try {
    for ($i = 0; $i -lt $MB; $i++) { $rng.GetBytes($bloco); $fs.Write($bloco, 0, $bloco.Length) }
  } finally { $fs.Close() }
}

# ---------- medições ----------
$csv = @('buffer_B,syscalls,tempo_s,MBps,us_por_read')
foreach ($b in 1, 16, 256, 4096, 65536, 1048576) {
  Limpar-Cache
  $linha = & .\io.exe $arq $b
  if ($LASTEXITCODE -ne 0) { throw "io.exe falhou com buffer $b" }
  Write-Host $linha
  $n = [regex]::Matches($linha, '[0-9]+(\.[0-9]+)?') | ForEach-Object { $_.Value }
  $csv += ($n[0..4] -join ',')
}
$csv | Set-Content -Path resultados.csv -Encoding Ascii

Write-Host ""
Write-Host "== fread com 1 byte =="
Limpar-Cache
& .\io_fread.exe $arq
if ($LASTEXITCODE -ne 0) { throw "io_fread.exe falhou" }

Write-Host ""
Write-Host "(O Windows nao tem strace: use a coluna 'syscalls' do io.exe para contar as chamadas.)"
Write-Host "Pronto! Abra resultados.csv numa planilha e plote MB/s x buffer (eixo X em escala log)."
