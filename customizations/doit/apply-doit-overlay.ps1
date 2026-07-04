[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$TargetPath
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$overlayRoot = Join-Path $scriptRoot "overlays"
$manifestPath = Join-Path $scriptRoot "manifest.json"

function Resolve-FullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Copy-OverlayFile {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $source = Join-Path $overlayRoot $RelativePath
  $target = Join-Path $targetFull $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Overlay file missing: $source"
  }
  $targetDir = Split-Path -Parent $target
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $target -Force
}

function Replace-InFile {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][object[]]$Replacements
  )
  $path = Join-Path $targetFull $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Target file missing: $path"
  }
  $content = [System.IO.File]::ReadAllText($path)
  foreach ($pair in $Replacements) {
    $content = $content.Replace([string]$pair[0], [string]$pair[1])
  }
  Write-Utf8NoBom -Path $path -Content $content
}

$targetFull = Resolve-FullPath -Path $TargetPath
if (-not (Test-Path -LiteralPath $targetFull -PathType Container)) {
  throw "Target path not found: $targetFull"
}
if (-not (Test-Path -LiteralPath (Join-Path $targetFull "frontend\src") -PathType Container)) {
  throw "Target path does not look like Sub2API: $targetFull"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Doit manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$overlayFiles = @($manifest.activeOverlayFiles)
if ($overlayFiles.Count -eq 0) {
  throw "Doit manifest has no activeOverlayFiles."
}

foreach ($relativePath in $overlayFiles) {
  Copy-OverlayFile -RelativePath $relativePath
}

$brandReplacements = @()
foreach ($replacement in @($manifest.brandReplacements)) {
  $brandReplacements += ,@([string]$replacement.from, [string]$replacement.to)
}
$brandFiles = @($manifest.brandFiles)
if ($brandReplacements.Count -eq 0 -or $brandFiles.Count -eq 0) {
  throw "Doit manifest must define brandReplacements and brandFiles."
}

foreach ($relativePath in $brandFiles) {
  Replace-InFile -RelativePath $relativePath -Replacements $brandReplacements
}

Write-Host "Applied Doit overlay files:"
foreach ($relativePath in $overlayFiles) {
  Write-Host "  - $relativePath"
}
Write-Host "Applied Doit brand replacements to i18n and auth layout files."
