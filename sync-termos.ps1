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

# -- Deriva entre a data dos termos e o aviso dentro do app -------------------
# O index.html tem a constante TERMOS_VERSAO, que decide se a barra "atualizamos
# os termos" aparece para quem ja usava o app. Se ela ficar para tras da data no
# topo de termos.html, o documento muda e ninguem e avisado — que e exatamente a
# promessa da secao 12 dos proprios termos. Este script ja existe para impedir
# que duas copias divirjam; a constante e a terceira copia da mesma informacao.
$appFile = Join-Path $here '../controle-financeiro/index.html'
$drift   = $false
if (Test-Path $appFile) {
  $termosTxt = [System.IO.File]::ReadAllText($source,  [System.Text.Encoding]::UTF8)
  $appTxt    = [System.IO.File]::ReadAllText($appFile, [System.Text.Encoding]::UTF8)
  $meses = @{ jan='01'; fev='02'; mar='03'; abr='04'; mai='05'; jun='06';
              jul='07'; ago='08'; set='09'; out='10'; nov='11'; dez='12' }
  # Sem contrabarra de proposito: [0-9] em vez de \d, [^ ] em vez de \S. Este
  # bloco ja foi escrito uma vez com \d e \s e chegou aqui sem as contrabarras,
  # comidas por uma camada de escape no caminho. O regex casou com nada, o teste
  # passou em silencio e o verificador nasceu morto. Classe de caractere explicita
  # nao tem como ser destruida assim.
  $mData = [regex]::Match($termosTxt, 'atualiza[^:]*: *([0-9]{1,2}) +de +([^ ]+) +de +([0-9]{4})')
  $mCons = [regex]::Match($appTxt,    "TERMOS_VERSAO *= *'([0-9-]+)'")
  if ($mData.Success -and $mCons.Success) {
    $chave = $mData.Groups[2].Value.Substring(0,3).ToLower()
    if ($meses.ContainsKey($chave)) {
      $esperado = '{0}-{1}-{2:D2}' -f $mData.Groups[3].Value, $meses[$chave], [int]$mData.Groups[1].Value
      $atual    = $mCons.Groups[1].Value
      if ($esperado -ne $atual) {
        $drift = $true
        Write-Host "DIVERGENCIA: termos.html diz $esperado e index.html tem TERMOS_VERSAO='$atual'." -ForegroundColor Red
        Write-Host "Quem ja usa o app nao sera avisado da mudanca. Atualize TERMOS_VERSAO e TERMOS_RESUMO no index.html."
      }
    }
  } else {
    Write-Host "Aviso: nao consegui ler a data dos termos ou a constante do app; deriva nao verificada." -ForegroundColor Yellow
  }
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
  if ($drift) { exit 1 }
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
if ($drift) { exit 1 }
exit 0
