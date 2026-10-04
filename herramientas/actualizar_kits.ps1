<#
  actualizar_kits.ps1 · Curso de Riesgos · Banco Atlántida

  Vuelve a incrustar (en base64) los archivos del kit de práctica dentro del HTML de cada módulo.

  Fuente:  recursos\ModuloN\Kit_Practica\<archivo>
  Destino: el bloque "var KIT_FILES = { ... }" de ModuloN_*.html (raíz del proyecto)

  Cada entrada de KIT_FILES indica el nombre del archivo que espera (name: '...').
  El script busca ese archivo en la carpeta del kit y reemplaza solo su base64;
  el resto del HTML no se toca.

  Uso:
    - Clic derecho > "Ejecutar con PowerShell"           (actualiza todos los módulos con kit)
    - powershell -File herramientas\actualizar_kits.ps1 -Modulo 3   (solo un módulo)
#>
param(
  [int]$Modulo = 0,       # 0 = todos los módulos que tengan KIT_FILES
  [switch]$SinPausa       # no esperar Enter al terminar
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web

# Convierte un .docx en HTML simple (títulos, párrafos y tablas) para el visor de documentos
function Convertir-DocxAHtml([string]$ruta) {
  $zip = [IO.Compression.ZipFile]::OpenRead($ruta)
  try {
    $lector = New-Object IO.StreamReader($zip.GetEntry('word/document.xml').Open())
    [xml]$xml = $lector.ReadToEnd(); $lector.Close()
  } finally { $zip.Dispose() }
  $ns = New-Object Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  $sb = New-Object Text.StringBuilder
  foreach ($n in $xml.SelectSingleNode('//w:body', $ns).ChildNodes) {
    if ($n.LocalName -eq 'p') {
      $texto = (@($n.SelectNodes('.//w:t', $ns)) | ForEach-Object { $_.InnerText }) -join ''
      if (-not $texto) { continue }
      $e = [System.Web.HttpUtility]::HtmlEncode($texto)
      $nodoEstilo = $n.SelectSingleNode('w:pPr/w:pStyle/@w:val', $ns)
      $estilo = if ($nodoEstilo) { $nodoEstilo.Value } else { '' }
      if ($estilo -eq 'Title') { [void]$sb.Append("<h1>$e</h1>") }
      elseif ($estilo -eq 'Heading1') { [void]$sb.Append("<h2>$e</h2>") }
      elseif ($estilo -like 'Heading*') { [void]$sb.Append("<h3>$e</h3>") }
      elseif ($texto -cmatch '^[^a-z]{12,}$') { [void]$sb.Append("<p class=`"small`">$e</p>") }   # línea en mayúsculas (antetítulo)
      else { [void]$sb.Append("<p>$e</p>") }
    } elseif ($n.LocalName -eq 'tbl') {
      [void]$sb.Append('<table>')
      foreach ($tr in $n.SelectNodes('w:tr', $ns)) {
        [void]$sb.Append('<tr>')
        foreach ($tc in $tr.SelectNodes('w:tc', $ns)) {
          $c = (@($tc.SelectNodes('.//w:t', $ns)) | ForEach-Object { $_.InnerText }) -join ''
          [void]$sb.Append('<td>' + [System.Web.HttpUtility]::HtmlEncode($c) + '</td>')
        }
        [void]$sb.Append('</tr>')
      }
      [void]$sb.Append('</table>')
    }
  }
  return $sb.ToString()
}

$raiz = Split-Path -Parent $PSScriptRoot
$utf8SinBom = New-Object System.Text.UTF8Encoding($false)
$patronEntrada = "(?m)^(\s*\w+:\s*\{\s*name:\s*'([^']+)',\s*mime:\s*'[^']*',\s*b64:\s*')([^']*)(')"
$hayErrores = $false

$paginas = Get-ChildItem -Path $raiz -Filter 'Modulo*_*.html' | Sort-Object Name
if ($Modulo -gt 0) { $paginas = $paginas | Where-Object { $_.Name -like "Modulo$($Modulo)_*" } }

foreach ($pagina in $paginas) {
  $num = [regex]::Match($pagina.Name, '^Modulo(\d+)_').Groups[1].Value
  $carpetaKit = Join-Path $raiz "recursos\Modulo$num\Kit_Practica"
  $html = [IO.File]::ReadAllText($pagina.FullName, $utf8SinBom)

  if ($html -notmatch 'var KIT_FILES = \{') { continue }
  Write-Host ""
  Write-Host "== $($pagina.Name) ==" -ForegroundColor Cyan

  if (-not (Test-Path $carpetaKit)) {
    Write-Host "  [ERROR] No existe la carpeta $carpetaKit" -ForegroundColor Red
    $hayErrores = $true
    continue
  }

  $faltantes = New-Object System.Collections.ArrayList
  $evaluador = {
    param($m)
    $nombre = $m.Groups[2].Value
    $ruta = Join-Path $carpetaKit $nombre
    if (-not (Test-Path $ruta)) {
      [void]$faltantes.Add($nombre)
      return $m.Value
    }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ruta))
    $estado = if ($b64 -eq $m.Groups[3].Value) { 'sin cambios' } else { 'ACTUALIZADO' }
    Write-Host ("  {0,-12} {1}" -f $estado, $nombre)
    return $m.Groups[1].Value + $b64 + $m.Groups[4].Value
  }

  $nuevo = [regex]::Replace($html, $patronEntrada, [System.Text.RegularExpressions.MatchEvaluator]$evaluador)

  foreach ($f in $faltantes) {
    Write-Host "  [ERROR] Falta en la carpeta del kit: $f (se conserva la versión incrustada)" -ForegroundColor Red
    $hayErrores = $true
  }

  # Vista previa de los Word (bloque KIT_PREVIEWS del visor de documentos)
  if ($nuevo -match 'var KIT_PREVIEWS = \{') {
    $nl = if ($nuevo.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lineas = foreach ($m in [regex]::Matches($nuevo, $patronEntrada)) {
      $nombre = $m.Groups[2].Value
      $ruta = Join-Path $carpetaKit $nombre
      if ($nombre -notmatch '\.docx$' -or -not (Test-Path $ruta)) { continue }
      $clave = [regex]::Match($m.Groups[1].Value, '^\s*(\w+):').Groups[1].Value
      $vista = (Convertir-DocxAHtml $ruta).Replace('\', '\\').Replace("'", "\'")
      "  ${clave}: '$vista',"
    }
    $bloque = 'var KIT_PREVIEWS = {' + $nl + (($lineas | ForEach-Object { $_ + $nl }) -join '') + '};'
    $nuevo = [regex]::Replace($nuevo, '(?s)var KIT_PREVIEWS = \{.*?\n\};', { param($x) $bloque })
    Write-Host "  vista previa  $(@($lineas).Count) documento(s) Word"
  }

  # Archivos que están en la carpeta pero el módulo no usa (p. ej. un archivo renombrado)
  $usados = [regex]::Matches($html, $patronEntrada) | ForEach-Object { $_.Groups[2].Value }
  Get-ChildItem $carpetaKit -File | Where-Object { $usados -notcontains $_.Name } | ForEach-Object {
    Write-Host "  [AVISO] $($_.Name) está en la carpeta pero el módulo no lo usa" -ForegroundColor Yellow
  }

  if ($nuevo -ne $html) {
    [IO.File]::WriteAllText($pagina.FullName, $nuevo, $utf8SinBom)
    Write-Host "  -> HTML guardado" -ForegroundColor Green
  } else {
    Write-Host "  -> Sin cambios en el HTML" -ForegroundColor Green
  }
}

Write-Host ""
if ($hayErrores) { Write-Host "Terminado con errores (revisa los mensajes en rojo)." -ForegroundColor Red }
else { Write-Host "Terminado." -ForegroundColor Green }
if (-not $SinPausa) { Read-Host "Presiona Enter para cerrar" | Out-Null }
if ($hayErrores) { exit 1 }
