[CmdletBinding()]
param(
  [string]$BackupPath = "",
  [string]$BackupRoot = ".\backups\sub2api-promote",
  [string]$TargetPath = ".\sub2api",
  [string]$PlanPath = ".\workbench\upstream-sync\reports\sub2api-rollback-plan-latest.json",
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

function Get-Version {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)
  $versionPath = Join-Path $ProjectPath "backend\cmd\server\VERSION"
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    return ""
  }
  return (Get-Content -LiteralPath $versionPath -Raw).Trim()
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

function Write-JsonRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Record
  )
  New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
  $json = $Record | ConvertTo-Json -Depth 8
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

function Find-LatestBackup {
  param([Parameter(Mandatory = $true)][string]$Root)
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    return ""
  }
  $latest = Get-ChildItem -LiteralPath $Root -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "backend\cmd\server\VERSION") -PathType Leaf } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $latest) {
    return ""
  }
  return $latest.FullName
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$backupRootFull = Resolve-PathFromRoot -Root $repoRoot -Path $BackupRoot
if ([string]::IsNullOrWhiteSpace($BackupPath)) {
  $BackupPath = Find-LatestBackup -Root $backupRootFull
}

$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$planFull = Resolve-PathFromRoot -Root $repoRoot -Path $PlanPath
Assert-PathInside -Child $backupRootFull -Parent $repoRoot -Purpose "Backup root"
Assert-PathInside -Child $targetFull -Parent $repoRoot -Purpose "Target"
Assert-PathInside -Child $planFull -Parent $repoRoot -Purpose "Plan"

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
  $record = [ordered]@{
    schema = "doit.sub2api.rollback-plan.v1"
    generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    mode = $(if ($Execute) { "execute" } else { "dry-run" })
    status = "blocked_no_backup"
    repo = $repoRoot
    paths = [ordered]@{
      backup_root = $backupRootFull
      target = $targetFull
      plan = $planFull
    }
  }
  Write-JsonRecord -Path $planFull -Record $record
  throw "No promotion backup found under $backupRootFull. Provide -BackupPath or create a promotion backup first."
}

$backupFull = Resolve-PathFromRoot -Root $repoRoot -Path $BackupPath
Assert-PathInside -Child $backupFull -Parent $repoRoot -Purpose "Backup"

if (-not (Test-Path -LiteralPath $backupFull -PathType Container)) {
  throw "Backup path not found: $backupFull"
}
if (-not (Test-Path -LiteralPath $targetFull -PathType Container)) {
  throw "Target project not found: $targetFull"
}
foreach ($required in @("backend\cmd\server\VERSION", "frontend\package.json", "deploy\docker-compose.local.yml")) {
  if (-not (Test-Path -LiteralPath (Join-Path $backupFull $required) -PathType Leaf)) {
    throw "Backup does not look like a restorable Sub2API project. Missing: $required"
  }
}

$backupVersion = Get-Version -ProjectPath $backupFull
$targetVersion = Get-Version -ProjectPath $targetFull
$targetHealth = Test-HttpReachable -Url $TargetHealthUrl

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

$rollbackRecord = [ordered]@{
  schema = "doit.sub2api.rollback-plan.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  mode = $(if ($Execute) { "execute" } else { "dry-run" })
  status = $(if ($Execute) { "planned" } else { "dry_run_ready" })
  repo = $repoRoot
  versions = [ordered]@{
    target = $targetVersion
    backup = $backupVersion
  }
  paths = [ordered]@{
    backup = $backupFull
    target = $targetFull
    plan = $planFull
  }
  checks = [ordered]@{
    target_health = [ordered]@{
      url = $TargetHealthUrl
      ok = [bool]$targetHealth.Ok
      detail = [string]$targetHealth.Detail
    }
    allow_running_target = [bool]$AllowRunningTarget
  }
  preserved_runtime_paths = @($preserveDirs + $preserveFiles)
}

Write-Host "Rollback plan:"
Write-Host "  backup:  $backupFull"
Write-Host "  target:  $targetFull"
Write-Host "  plan:    $planFull"
Write-Host "  version: $targetVersion -> $backupVersion"
Write-Host "  target health: $TargetHealthUrl $($targetHealth.Detail)"
Write-Host "Preserved runtime paths:"
foreach ($path in ($preserveDirs + $preserveFiles)) {
  Write-Host "  - $path"
}

Write-JsonRecord -Path $planFull -Record $rollbackRecord
Write-Host "Rollback plan record written: $planFull"

if (-not $Execute) {
  Write-Host ""
  Write-Host "Dry run only. Stop the target runtime first, then re-run with -Execute to restore the backup into the current sub2api directory."
  exit 0
}

if ($targetHealth.Ok -and -not $AllowRunningTarget) {
  $rollbackRecord["status"] = "blocked_target_running"
  Write-JsonRecord -Path $planFull -Record $rollbackRecord
  throw "Refusing to execute rollback while the target runtime is reachable at $TargetHealthUrl ($($targetHealth.Detail)). Stop the target container first, or pass -AllowRunningTarget only for an intentional hot overwrite."
}

$runtimeBackup = Join-Path $targetFull "_rollback-runtime-preserved"
if (Test-Path -LiteralPath $runtimeBackup) {
  Remove-Item -LiteralPath $runtimeBackup -Recurse -Force
}
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
  $backupFull,
  $targetFull,
  "/MIR",
  "/XD", ".git", "node_modules", "dist", "data", "postgres_data", "redis_data", "backups", "caddy_data", "caddy_config", "_runtime-preserved", "_rollback-runtime-preserved",
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
Remove-Item -LiteralPath $runtimeBackup -Recurse -Force

Write-Host "Rollback completed."
Write-Host "Runtime files were preserved and not printed."

$rollbackRecord["status"] = "completed"
$rollbackRecord["completed_at"] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Write-JsonRecord -Path $planFull -Record $rollbackRecord
Write-Host "Rollback completion record written: $planFull"
