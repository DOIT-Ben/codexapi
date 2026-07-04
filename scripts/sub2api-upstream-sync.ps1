[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$StagingPath = "",
  [string]$ManifestPath = ".\customizations\doit\manifest.json",
  [string]$PatchDir = ".\customizations\doit\patches",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  $root = (& git rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
    throw "This script must run inside the codexapi git repository."
  }
  return [System.IO.Path]::GetFullPath($root.Trim())
}

function Resolve-PathFromRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Assert-PathInside {
  param(
    [Parameter(Mandatory = $true)][string]$Child,
    [Parameter(Mandatory = $true)][string]$Parent,
    [Parameter(Mandatory = $true)][string]$Purpose
  )

  $parentWithSlash = $Parent.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $Child.StartsWith($parentWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Purpose path must stay under $Parent. Got: $Child"
  }
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FilePath $($Arguments -join ' ')"
  }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$manifestFull = Resolve-PathFromRoot -Root $repoRoot -Path $ManifestPath
$patchFull = Resolve-PathFromRoot -Root $repoRoot -Path $PatchDir
$overlayScript = Resolve-PathFromRoot -Root $repoRoot -Path ".\customizations\doit\apply-doit-overlay.ps1"
$allowedStagingRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "workbench\upstream-sync"))

if (-not (Test-Path -LiteralPath $officialFull -PathType Container)) {
  throw "Official source not found: $officialFull"
}
if (-not (Test-Path -LiteralPath (Join-Path $officialFull "backend\cmd\server\VERSION") -PathType Leaf)) {
  throw "Official source does not look like Sub2API: $officialFull"
}
if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) {
  throw "Doit manifest not found: $manifestFull"
}
$manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json
$officialVersion = (Get-Content -LiteralPath (Join-Path $officialFull "backend\cmd\server\VERSION") -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$officialVersion"
}
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
if (-not (Test-Path -LiteralPath $patchFull -PathType Container)) {
  throw "Patch directory not found: $patchFull"
}
$overlayScriptName = [string]$manifest.overlayScript
if (-not [string]::IsNullOrWhiteSpace($overlayScriptName)) {
  $overlayScript = Resolve-PathFromRoot -Root $repoRoot -Path (Join-Path ".\customizations\doit" $overlayScriptName)
}
if (-not (Test-Path -LiteralPath $overlayScript -PathType Leaf)) {
  throw "Doit overlay script not found: $overlayScript"
}

Assert-PathInside -Child $stagingFull -Parent $allowedStagingRoot -Purpose "Staging"

if (Test-Path -LiteralPath $stagingFull) {
  if (-not $Force) {
    throw "Staging path already exists. Re-run with -Force to recreate it: $stagingFull"
  }
  Remove-Item -LiteralPath $stagingFull -Recurse -Force
}

New-Item -ItemType Directory -Path $allowedStagingRoot -Force | Out-Null

$robocopyArgs = @(
  $officialFull,
  $stagingFull,
  "/E",
  "/XD", ".git", "data", "postgres_data", "redis_data",
  "/XF", ".env",
  "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
)
& robocopy @robocopyArgs | Out-Null
if ($LASTEXITCODE -gt 7) {
  throw "robocopy failed with exit code $LASTEXITCODE"
}

Invoke-Checked -FilePath "git" -Arguments @("-C", $stagingFull, "init", "-q")

$activePatchNames = @($manifest.activePatches)
if ($activePatchNames.Count -eq 0) {
  throw "Doit manifest has no activePatches."
}
$patches = @()
foreach ($patchName in $activePatchNames) {
  $patchPath = Join-Path $patchFull $patchName
  if (-not (Test-Path -LiteralPath $patchPath -PathType Leaf)) {
    throw "Active patch from manifest not found: $patchPath"
  }
  $patches += Get-Item -LiteralPath $patchPath
}

$applied = @()
foreach ($patch in $patches) {
  Invoke-Checked -FilePath "git" -Arguments @("-C", $stagingFull, "apply", "--check", "--whitespace=nowarn", $patch.FullName)
  Invoke-Checked -FilePath "git" -Arguments @("-C", $stagingFull, "apply", "--whitespace=nowarn", $patch.FullName)
  $applied += $patch.Name
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $overlayScript -TargetPath $stagingFull
if ($LASTEXITCODE -ne 0) {
  throw "Doit overlay failed."
}

$version = (Get-Content -LiteralPath (Join-Path $stagingFull "backend\cmd\server\VERSION") -Raw).Trim()

Write-Host "Official source: $officialFull"
Write-Host "Staging path:   $stagingFull"
Write-Host "Version:        $version"
Write-Host "Applied patches:"
foreach ($name in $applied) {
  Write-Host "  - $name"
}
Write-Host "Applied overlay: customizations\doit\apply-doit-overlay.ps1"
Write-Host "No .env, database data, Redis data, or secrets were copied from the current local deployment."
