[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$TargetPath = ".\sub2api",
  [string]$StagingPath = "",
  [string]$ManifestPath = ".\customizations\doit\manifest.json",
  [string]$ReportPath = "",
  [switch]$CheckHttp,
  [string]$TargetHealthUrl = "http://127.0.0.1:18082/health",
  [string]$StagingHealthUrl = "http://127.0.0.1:18083/health"
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

function Get-Version {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)
  $versionPath = Join-Path $ProjectPath "backend\cmd\server\VERSION"
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    return ""
  }
  return (Get-Content -LiteralPath $versionPath -Raw).Trim()
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

function Get-PatchTouchedFiles {
  param([Parameter(Mandatory = $true)][string]$PatchDir)
  if (-not (Test-Path -LiteralPath $PatchDir -PathType Container)) {
    return @()
  }
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($patch in (Get-ChildItem -LiteralPath $PatchDir -Filter "*.patch" | Sort-Object Name)) {
    foreach ($line in (Get-Content -LiteralPath $patch.FullName)) {
      if ($line -match "^diff --git a/(.+?) b/(.+)$") {
        $files.Add(("{0} -> {1}" -f $patch.Name, $Matches[2]))
      }
    }
  }
  return $files.ToArray()
}

function Test-HttpHealth {
  param([Parameter(Mandatory = $true)][string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8
    return ("{0} status={1}" -f $Url, $response.StatusCode)
  } catch {
    return ("{0} ERROR={1}" -f $Url, $_.Exception.Message)
  }
}

function Add-ListSection {
  param(
    [System.Collections.Generic.List[string]]$OutputLines,
    [Parameter(Mandatory = $true)][string]$Title,
    [string[]]$Items = @(),
    [string]$EmptyText = "none"
  )
  [void]$OutputLines.Add("")
  [void]$OutputLines.Add("## $Title")
  if ($Items.Count -eq 0) {
    [void]$OutputLines.Add("")
    [void]$OutputLines.Add("- $EmptyText")
    return
  }
  foreach ($item in $Items) {
    [void]$OutputLines.Add("- $item")
  }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  if ([string]::IsNullOrWhiteSpace($lockVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$lockVersion"
}

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$manifestFull = Resolve-PathFromRoot -Root $repoRoot -Path $ManifestPath
$overlayRoot = Join-Path $repoRoot "customizations\doit\overlays"
$patchRoot = Join-Path $repoRoot "customizations\doit\patches"
$manifest = $null
if (Test-Path -LiteralPath $manifestFull -PathType Leaf) {
  $manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json
}

$officialCommit = if (Test-Path -LiteralPath $officialFull -PathType Container) { (& git -C $officialFull rev-parse HEAD).Trim() } else { "" }
$officialRemote = if (Test-Path -LiteralPath $officialFull -PathType Container) { (& git -C $officialFull remote get-url origin).Trim() } else { "" }
$officialVersion = if (Test-Path -LiteralPath $officialFull -PathType Container) { Get-Version -ProjectPath $officialFull } else { "" }
$targetVersion = if (Test-Path -LiteralPath $targetFull -PathType Container) { Get-Version -ProjectPath $targetFull } else { "" }
$stagingVersion = if (Test-Path -LiteralPath $stagingFull -PathType Container) { Get-Version -ProjectPath $stagingFull } else { "" }

$overlayFiles = @()
if ($manifest -and $manifest.activeOverlayFiles) {
  $overlayFiles = @($manifest.activeOverlayFiles)
} elseif (Test-Path -LiteralPath $overlayRoot -PathType Container) {
  $overlayFiles = Get-ChildItem -LiteralPath $overlayRoot -Recurse -File |
    Sort-Object FullName |
    ForEach-Object { $_.FullName.Substring($overlayRoot.Length + 1) }
}

$activePatches = @()
if ($manifest -and $manifest.activePatches) {
  $activePatches = @($manifest.activePatches)
} elseif (Test-Path -LiteralPath $patchRoot -PathType Container) {
  $activePatches = Get-ChildItem -LiteralPath $patchRoot -Filter "*.patch" |
    Sort-Object Name |
    ForEach-Object { $_.Name }
}

$patchTouchedFiles = Get-PatchTouchedFiles -PatchDir $patchRoot
$preservedRuntime = @(
  "deploy\.env",
  "deploy\config.yaml",
  "deploy\data",
  "deploy\postgres_data",
  "deploy\redis_data",
  "deploy\backups",
  "deploy\caddy_data",
  "deploy\caddy_config"
)

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# Sub2API Upstream Absorption Report")
[void]$lines.Add("")
[void]$lines.Add(("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")))
[void]$lines.Add(("Repository: {0}" -f $repoRoot))
[void]$lines.Add("")
[void]$lines.Add("## Versions")
[void]$lines.Add(("- official_remote: {0}" -f $(if ($officialRemote) { $officialRemote } else { "missing" })))
[void]$lines.Add(("- official_commit: {0}" -f $(if ($officialCommit) { $officialCommit } else { "missing" })))
[void]$lines.Add(("- official_version: {0}" -f $(if ($officialVersion) { $officialVersion } else { "missing" })))
[void]$lines.Add(("- target_version: {0}" -f $(if ($targetVersion) { $targetVersion } else { "missing" })))
[void]$lines.Add(("- staging_version: {0}" -f $(if ($stagingVersion) { $stagingVersion } else { "missing" })))
[void]$lines.Add(("- lock_version: {0}" -f $(if ($lockVersion) { $lockVersion } else { "missing" })))

Add-ListSection -OutputLines $lines -Title "Overlay Files" -Items $overlayFiles -EmptyText "no overlay files"
Add-ListSection -OutputLines $lines -Title "Active Patches" -Items $activePatches -EmptyText "no active patches"
Add-ListSection -OutputLines $lines -Title "Patch-Touched Files" -Items $patchTouchedFiles -EmptyText "no patch-touched files"
Add-ListSection -OutputLines $lines -Title "Promotion Preserved Runtime Paths" -Items $preservedRuntime

if ($CheckHttp) {
  Add-ListSection -OutputLines $lines -Title "HTTP Health" -Items @(
    (Test-HttpHealth -Url $TargetHealthUrl),
    (Test-HttpHealth -Url $StagingHealthUrl)
  )
}

[void]$lines.Add("")
[void]$lines.Add("## Promotion Boundary")
[void]$lines.Add("- This report is read-only.")
[void]$lines.Add("- It does not fetch upstream, regenerate staging, stop containers, or replace the target project.")
[void]$lines.Add("- Formal promotion still requires an explicit user approval and `scripts\sub2api-promote-staging.ps1 -Execute`.")

$reportText = $lines -join [Environment]::NewLine
Write-Output $reportText

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
  $reportFull = Resolve-PathFromRoot -Root $repoRoot -Path $ReportPath
  New-Item -ItemType Directory -Path (Split-Path -Parent $reportFull) -Force | Out-Null
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($reportFull, $reportText + [Environment]::NewLine, $encoding)
  Write-Host ""
  Write-Host "Report written: $reportFull"
}
