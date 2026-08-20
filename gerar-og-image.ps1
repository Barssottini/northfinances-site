<#
.SYNOPSIS
  Gera og-image.png (1200x630) a partir de og-image.html usando o Edge headless.

.DESCRIPTION
  A imagem de previa de link e GERADA, nao desenhada a mao. A fonte e og-image.html,
  que usa as fontes e cores reais da marca - entao a previa nunca fica fora do padrao
  por engano, e mudar a arte e editar HTML em vez de abrir um editor de imagem.

  Rode depois de qualquer alteracao em og-image.html e commite o PNG.

.PARAMETER Retina
  Renderiza em 2x (2400x1260, ~1,5 MB) em vez de 1x (1200x630, ~460 KB).
  O padrao 1x e o tamanho recomendado pela Meta e carrega mais rapido na previa.

.EXAMPLE
  .\gerar-og-image.ps1
#>
[CmdletBinding()]
param([switch]$Retina)

$ErrorActionPreference = 'Stop'

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $here 'og-image.html'
$dest   = Join-Path $here 'og-image.png'

if (-not (Test-Path $source)) {
  Write-Host "Nao encontrei og-image.html em $here" -ForegroundColor Red
  exit 2
}

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $edge) {
  Write-Host "Microsoft Edge nao encontrado. Ele e usado no modo headless para renderizar." -ForegroundColor Red
  exit 2
}

$scale = 1
if ($Retina) { $scale = 2 }

$edgeArgs = @(
  '--headless','--disable-gpu','--hide-scrollbars',
  '--window-size=1200,630',
  "--force-device-scale-factor=$scale",
  '--virtual-time-budget=8000',   # espera as fontes do Google carregarem
  "--screenshot=$dest",
  "file:///$($source -replace '\\','/')"
)

# Chamada direta com splat: o Edge recebe cada argumento separado, o que preserva os
# espacos de "Area de Trabalho" nos caminhos. Nao redirecionar stderr aqui: o Edge
# escreve um aviso inofensivo do task_manager, e no PowerShell 5.1 redirecionar stderr
# de executavel nativo vira NativeCommandError e derruba o script mesmo com exit 0.
# O aviso aparece no console e pode ser ignorado.
& $edge @edgeArgs | Out-Null

if (-not (Test-Path $dest)) {
  Write-Host "A renderizacao nao produziu arquivo." -ForegroundColor Red
  exit 1
}

$kb = [math]::Round((Get-Item $dest).Length / 1KB)
Write-Host "og-image.png gerada (${scale}x, ~$kb KB)." -ForegroundColor Green
Write-Host "Confira o texto letra por letra antes de commitar - a previa aparece em WhatsApp, Facebook e LinkedIn."
exit 0
