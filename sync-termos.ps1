<#
.SYNOPSIS
  Copia o termos.html canonico do repo do app para o repo do site.

.DESCRIPTION
  A politica de privacidade tem UM original: controle-financeiro/termos.html.
  O site institucional precisa servi-la no proprio dominio
  (northfinances.com.br/termos.html) porque e o dominio que grava o cookie de
  medicao da Meta. Mas manter duas copias editaveis e o jeito garantido de elas
  divergirem, que e exatamente o problema que a revisao de agosto/2026 apontou.

  Entao a copia do site e GERADA, nunca editada a mao. Rode este script depois de
  qualquer alteracao nos termos e commite o resultado nos dois repositorios.

.PARAMETER Check
  Nao escreve nada; so verifica se a copia esta em dia. Sai com codigo 1 se
  estiver desatualizada, para prender num hook de pre-commit ou em CI.

.EXAMPLE
  .\sync-termos.ps1

.EXAMPLE
  .\sync-termos.ps1 -Check
#>
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $here '..\controle-financeiro\termos.html'
$dest   = Join-Path $here 'termos.html'

if (-not (Test-Path $source)) {
  Write-Host "Original nao encontrado: $source" -ForegroundColor Red
  Write-Host "Este script espera que controle-financeiro e northfinances-site sejam pastas irmas."
  exit 2
}

$banner = @'
<!--
  ARQUIVO GERADO - NAO EDITE AQUI.
  Original: controle-financeiro/termos.html
  Para atualizar: rode northfinances-site/sync-termos.ps1 e commite o resultado.
  Editar esta copia direto faz as duas versoes divergirem, que e exatamente
  o problema que este arquivo existe para evitar.
-->
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$content   = [System.IO.File]::ReadAllText($source, [System.Text.Encoding]::UTF8)

# Injeta o aviso logo apos o doctype.
$pattern  = '(?i)^(<!DOCTYPE html>\r?\n)'
# O termos.html e CRLF, mas o here-string acima produz LF. Injetar sem
# normalizar deixa as 7 linhas do aviso fora do padrao do documento e suja
# todo diff futuro do arquivo gerado — exatamente o ruido que o .gitattributes
# foi criado para eliminar.
$bannerCRLF = ($banner -replace "`r`n", "`n") -replace "`n", "`r`n"
$expected = [System.Text.RegularExpressions.Regex]::Replace(
  $content, $pattern, ('$1' + $bannerCRLF + "`r`n"), 'None')

if ($expected -eq $content) {
  Write-Host "Nao encontrei '<!DOCTYPE html>' na primeira linha de $source." -ForegroundColor Red
  Write-Host "O banner nao foi injetado; nada foi escrito."
  exit 2
}

$current = ''
if (Test-Path $dest) {
  $current = [System.IO.File]::ReadAllText($dest, [System.Text.Encoding]::UTF8)
}

if ($current -eq $expected) {
  Write-Host "termos.html ja esta em dia." -ForegroundColor Green
  exit 0
}

if ($Check) {
  Write-Host "termos.html do site esta DESATUALIZADO." -ForegroundColor Yellow
  Write-Host "Rode: .\sync-termos.ps1"
  exit 1
}

[System.IO.File]::WriteAllText($dest, $expected, $utf8NoBom)
Write-Host "termos.html atualizado a partir de controle-financeiro/termos.html" -ForegroundColor Green
Write-Host "Commite nos DOIS repositorios."
exit 0
