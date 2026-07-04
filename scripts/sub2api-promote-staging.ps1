[CmdletBinding()]
param(
  [string]$StagingPath = "",
  [string]$TargetPath = ".\sub2api",
  [string]$BackupRoot = ".\backups\sub2api-promote",
  [string]$ReportPath = "",
  [string]$TargetHealthUrl = "http://127.0.0.1:18082/health",
  [switch]$AllowRunningTarget,
  [switch]$Execute
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

function Invoke-RobocopyChecked {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)
  & robocopy @Arguments | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
  }
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

function Get-Version {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)
  $versionPath = Join-Path $ProjectPath "backend\cmd\server\VERSION"
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    return ""
  }
  return (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

function Test-AbsorptionReport {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$TargetVersion,
    [Parameter(Mandatory = $true)][string]$StagingVersion,
    [string]$OfficialCommit = ""
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "missing report"
    }
  }

  $content = Get-Content -LiteralPath $Path -Raw
  $failed = @()
  if (-not $content.Contains("- target_version: $TargetVersion")) {
    $failed += "target_version"
  }
  if (-not $content.Contains("- staging_version: $StagingVersion")) {
    $failed += "staging_version"
  }
  if (-not [string]::IsNullOrWhiteSpace($OfficialCommit) -and -not $content.Contains("- official_commit: $OfficialCommit")) {
    $failed += "official_commit"
  }

  if ($failed.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "stale fields: $($failed -join ', ')"
    }
  }

  return [pscustomobject]@{
    Ok = $true
    Detail = "report matches current versions"
  }
}

function Test-HttpReachable {
  param([Parameter(Mandatory = $true)][string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return [pscustomobject]@{
      Ok = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
      Detail = "status=$($response.StatusCode)"
    }
  } catch {
    return [pscustomobject]@{
      Ok = $false
      Detail = $_.Exception.Message
    }
  }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  $lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
  if ([string]::IsNullOrWhiteSpace($lockVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$lockVersion"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = ".\workbench\upstream-sync\reports\sub2api-upstream-report-latest.md"
}

$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$backupRootFull = Resolve-PathFromRoot -Root $repoRoot -Path $BackupRoot
$reportFull = Resolve-PathFromRoot -Root $repoRoot -Path $ReportPath

Assert-PathInside -Child $stagingFull -Parent $repoRoot -Purpose "Staging"
Assert-PathInside -Child $targetFull -Parent $repoRoot -Purpose "Target"
Assert-PathInside -Child $backupRootFull -Parent $repoRoot -Purpose "Backup"
Assert-PathInside -Child $reportFull -Parent $repoRoot -Purpose "Report"

if (-not (Test-Path -LiteralPath $stagingFull -PathType Container)) {
  throw "Staging source not found: $stagingFull"
}
if (-not (Test-Path -LiteralPath $targetFull -PathType Container)) {
  throw "Target project not found: $targetFull"
}
foreach ($required in @("backend\cmd\server\VERSION", "frontend\package.json", "deploy\docker-compose.local.yml")) {
  if (-not (Test-Path -LiteralPath (Join-Path $stagingFull $required) -PathType Leaf)) {
    throw "Staging source is missing required file: $required"
  }
}

$version = Get-Version -ProjectPath $stagingFull
$targetVersion = Get-Version -ProjectPath $targetFull
$reportCheck = Test-AbsorptionReport -Path $reportFull -TargetVersion $targetVersion -StagingVersion $version -OfficialCommit $lockCommit
$targetHealth = Test-HttpReachable -Url $TargetHealthUrl
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFull = Join-Path $backupRootFull "sub2api_$timestamp"

$preserveDirs = @(
  "deploy\data",
  "deploy\postgres_data",
  "deploy\redis_data",
  "deploy\backups",
  "deploy\caddy_data",
  "deploy\caddy_config"
)
$preserveFiles = @(
  "deploy\.env",
  "deploy\config.yaml"
)

Write-Host "Promotion plan:"
Write-Host "  staging: $stagingFull"
Write-Host "  target:  $targetFull"
Write-Host "  backup:  $backupFull"
Write-Host "  report:  $reportFull"
Write-Host "  version: $version"
Write-Host "  report check: $($reportCheck.Detail)"
Write-Host "  target health: $TargetHealthUrl $($targetHealth.Detail)"
Write-Host "Preserved runtime paths:"
foreach ($path in ($preserveDirs + $preserveFiles)) {
  Write-Host "  - $path"
}

if (-not $Execute) {
  Write-Host ""
  Write-Host "Dry run only. Stop the target runtime first, then re-run with -Execute to promote staging into the current sub2api directory."
  exit 0
}

if (-not $reportCheck.Ok) {
  throw "Refusing to execute promotion because the upstream absorption report is not current: $($reportCheck.Detail)"
}
if ($targetHealth.Ok -and -not $AllowRunningTarget) {
  throw "Refusing to execute promotion while the target runtime is reachable at $TargetHealthUrl ($($targetHealth.Detail)). Stop the target container first, or pass -AllowRunningTarget only for an intentional hot overwrite."
}

New-Item -ItemType Directory -Path $backupFull -Force | Out-Null

Invoke-RobocopyChecked -Arguments @(
  $targetFull,
  $backupFull,
  "/E",
  "/XD", ".git", "node_modules", "dist", "data", "postgres_data", "redis_data", "backups", "caddy_data", "caddy_config",
  "/XF", ".env", ".env.*", "config.yaml", "*.log", "*.tmp",
  "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
)

$runtimeBackup = Join-Path $backupFull "_runtime-preserved"
New-Item -ItemType Directory -Path $runtimeBackup -Force | Out-Null
foreach ($relativePath in $preserveFiles) {
  $source = Join-Path $targetFull $relativePath
  if (Test-Path -LiteralPath $source -PathType Leaf) {
    $destination = Join-Path $runtimeBackup $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}

Invoke-RobocopyChecked -Arguments @(
  $stagingFull,
  $targetFull,
  "/MIR",
  "/XD", ".git", "node_modules", "dist", "data", "postgres_data", "redis_data", "backups", "caddy_data", "caddy_config",
  "/XF", ".env", ".env.*", "config.yaml", "*.log", "*.tmp",
  "/NFL", "/NDL", "/NJH", "/NJS", "/NP"
)

foreach ($relativePath in $preserveFiles) {
  $source = Join-Path $runtimeBackup $relativePath
  if (Test-Path -LiteralPath $source -PathType Leaf) {
    $destination = Join-Path $targetFull $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}

Write-Host "Promotion completed."
Write-Host "Backup created at: $backupFull"
Write-Host "Runtime files were preserved and not printed."
