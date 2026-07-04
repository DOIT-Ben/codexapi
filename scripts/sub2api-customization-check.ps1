[CmdletBinding()]
param(
  [string]$ManifestPath = ".\customizations\doit\manifest.json",
  [string]$StagingPath = "",
  [string]$ReportPath = ".\workbench\upstream-sync\reports\sub2api-customization-check-latest.json"
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

function Get-UpstreamLockValue {
  param(
    [Parameter(Mandatory = $true)][string]$LockPath,
    [Parameter(Mandatory = $true)][string]$Name
  )
  if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) {
    return ""
  }
  foreach ($line in Get-Content -LiteralPath $LockPath) {
    if ($line -match "^\s*([^=]+)=(.*)$" -and $Matches[1].Trim() -eq $Name) {
      return $Matches[2].Trim()
    }
  }
  return ""
}

function Get-FileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ""
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256 {
  param([Parameter(Mandatory = $true)][string]$Content)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $sha.Dispose()
  }
}

function Get-ExpectedOverlayContent {
  param(
    [Parameter(Mandatory = $true)][string]$OverlayPath,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][object]$Manifest
  )
  if (-not (Test-Path -LiteralPath $OverlayPath -PathType Leaf)) {
    return ""
  }
  $content = [System.IO.File]::ReadAllText($OverlayPath)
  if (@($Manifest.brandFiles) -contains $RelativePath) {
    foreach ($replacement in @($Manifest.brandReplacements)) {
      $content = $content.Replace([string]$replacement.from, [string]$replacement.to)
    }
  }
  return $content
}

function Write-JsonRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Record
  )
  New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
  $json = $Record | ConvertTo-Json -Depth 10
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

function Add-Check {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Ok,
    [string]$Detail = ""
  )
  $Checks.Add([ordered]@{
    name = $Name
    ok = $Ok
    detail = $Detail
  })
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$manifestFull = Resolve-PathFromRoot -Root $repoRoot -Path $ManifestPath
$reportFull = Resolve-PathFromRoot -Root $repoRoot -Path $ReportPath
if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) {
  throw "Manifest not found: $manifestFull"
}

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  if ([string]::IsNullOrWhiteSpace($lockVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$lockVersion"
}
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$customRoot = Split-Path -Parent $manifestFull
$overlayRoot = Join-Path $customRoot "overlays"
$manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json

$checks = New-Object System.Collections.Generic.List[object]
Add-Check -Checks $checks -Name "staging exists" -Ok (Test-Path -LiteralPath $stagingFull -PathType Container) -Detail $stagingFull

foreach ($relativePath in @($manifest.activeOverlayFiles)) {
  $overlayPath = Join-Path $overlayRoot $relativePath
  $stagingPathFull = Join-Path $stagingFull $relativePath
  $expectedContent = Get-ExpectedOverlayContent -OverlayPath $overlayPath -RelativePath $relativePath -Manifest $manifest
  $stagingContent = if (Test-Path -LiteralPath $stagingPathFull -PathType Leaf) { [System.IO.File]::ReadAllText($stagingPathFull) } else { "" }
  $expectedHash = if ($expectedContent) { Get-StringSha256 -Content $expectedContent } else { "" }
  $stagingHash = if ($stagingContent) { Get-StringSha256 -Content $stagingContent } else { "" }
  $ok = (-not [string]::IsNullOrWhiteSpace($expectedHash)) -and $expectedHash -eq $stagingHash
  Add-Check -Checks $checks -Name "overlay matches $relativePath" -Ok $ok -Detail "expected=$expectedHash staging=$stagingHash"
}

$brandReplacement = @($manifest.brandReplacements | Where-Object { $_.from -eq "Sub2API" } | Select-Object -First 1)
if ($brandReplacement.Count -gt 0) {
  foreach ($relativePath in @($manifest.brandFiles)) {
    $path = Join-Path $stagingFull $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      Add-Check -Checks $checks -Name "brand file exists $relativePath" -Ok $false -Detail "missing"
      continue
    }
    $content = [System.IO.File]::ReadAllText($path)
    $ok = $content.Contains([string]$brandReplacement[0].to) -and -not $content.Contains([string]$brandReplacement[0].from)
    Add-Check -Checks $checks -Name "brand replacement applied $relativePath" -Ok $ok -Detail "$($brandReplacement[0].from) -> $($brandReplacement[0].to)"
  }
}

$failed = @($checks | Where-Object { -not $_.ok })
$result = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$record = [ordered]@{
  schema = "doit.sub2api.customization-check.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = $result
  manifest = $manifestFull
  staging = $stagingFull
  checks = $checks.ToArray()
}
Write-JsonRecord -Path $reportFull -Record $record

Write-Host "Sub2API customization check"
Write-Host "  manifest: $manifestFull"
Write-Host "  staging:  $stagingFull"
Write-Host "  report:   $reportFull"
foreach ($check in $checks) {
  $status = if ($check.ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1} - {2}" -f $status, $check.name, $check.detail)
}
Write-Host "Customization check result: $result"

if ($result -ne "PASS") {
  exit 1
}
