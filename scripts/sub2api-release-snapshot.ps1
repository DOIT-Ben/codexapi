[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$TargetPath = ".\sub2api",
  [string]$StagingPath = "",
  [string]$SnapshotPath = ".\workbench\upstream-sync\reports\sub2api-release-snapshot-latest.json",
  [switch]$CheckRemote,
  [switch]$SkipHttp,
  [switch]$SkipPreflight
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

function Get-ProjectVersion {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)
  $versionPath = Join-Path $ProjectPath "backend\cmd\server\VERSION"
  if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    return ""
  }
  return (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

function Get-GitValue {
  param(
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $value = (& git -C $WorkingDirectory @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) {
    return ""
  }
  return ($value -join "`n").Trim()
}

function Test-HealthUrl {
  param([Parameter(Mandatory = $true)][string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return [ordered]@{
      ok = ($response.StatusCode -eq 200)
      status = [int]$response.StatusCode
      error = ""
    }
  } catch {
    return [ordered]@{
      ok = $false
      status = 0
      error = $_.Exception.Message
    }
  }
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

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  $exitCode = $LASTEXITCODE
  return [ordered]@{
    exit_code = $exitCode
    output = $output
  }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockRepo = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_repo"
$lockRef = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_ref"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($lockVersion)) {
  $lockVersion = "unknown"
}
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$lockVersion"
}

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$snapshotFull = Resolve-PathFromRoot -Root $repoRoot -Path $SnapshotPath
$promotionPlanPath = Resolve-PathFromRoot -Root $repoRoot -Path ".\workbench\upstream-sync\reports\sub2api-promotion-plan-latest.json"
$rollbackPlanPath = Resolve-PathFromRoot -Root $repoRoot -Path ".\workbench\upstream-sync\reports\sub2api-rollback-plan-latest.json"

$statusLines = @(& git status --porcelain)
$sub2apiDiffs = @(& git diff --name-only -- sub2api | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$head = (& git rev-parse HEAD).Trim()
$originHead = (& git rev-parse origin/main 2>$null)
if ($LASTEXITCODE -ne 0) {
  $originHead = ""
} else {
  $originHead = ($originHead -join "`n").Trim()
}

$officialRemote = if (Test-Path -LiteralPath $officialFull -PathType Container) { Get-GitValue -WorkingDirectory $officialFull -Arguments @("remote", "get-url", "origin") } else { "" }
$officialHead = if (Test-Path -LiteralPath $officialFull -PathType Container) { Get-GitValue -WorkingDirectory $officialFull -Arguments @("rev-parse", "HEAD") } else { "" }
$officialStatus = if (Test-Path -LiteralPath $officialFull -PathType Container) { Get-GitValue -WorkingDirectory $officialFull -Arguments @("status", "--porcelain") } else { "missing" }
$remoteMain = ""
if ($CheckRemote -and -not [string]::IsNullOrWhiteSpace($officialRemote)) {
  $remoteLine = (& git ls-remote $officialRemote refs/heads/main 2>$null)
  if ($LASTEXITCODE -eq 0 -and $remoteLine) {
    $remoteMain = (($remoteLine -join "`n") -split "\s+")[0]
  }
}

$health = [ordered]@{}
if (-not $SkipHttp) {
  $health["target"] = Test-HealthUrl -Url "http://127.0.0.1:18082/health"
  $health["staging"] = Test-HealthUrl -Url "http://127.0.0.1:18083/health"
}

$preflight = [ordered]@{
  skipped = [bool]$SkipPreflight
  exit_code = $null
  result = ""
}
if (-not $SkipPreflight) {
  $preflightCapture = Invoke-Capture -FilePath "powershell" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $repoRoot "scripts\sub2api-promotion-preflight.ps1")
  )
  $preflight["exit_code"] = $preflightCapture.exit_code
  $resultLine = @($preflightCapture.output | Where-Object { $_ -like "Preflight result:*" } | Select-Object -Last 1)
  if ($resultLine.Count -gt 0) {
    $preflight["result"] = $resultLine[0]
  }
}

$promotionPlan = Read-JsonFile -Path $promotionPlanPath
$rollbackPlan = Read-JsonFile -Path $rollbackPlanPath

$snapshot = [ordered]@{
  schema = "doit.sub2api.release-snapshot.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  repo = $repoRoot
  git = [ordered]@{
    branch = (& git branch --show-current).Trim()
    head = $head
    origin_main = $originHead
    synced_with_origin = ($head -eq $originHead)
    working_tree_entries = $statusLines.Count
    sub2api_diff_count = $sub2apiDiffs.Count
    sub2api_diff_paths = @($sub2apiDiffs)
  }
  upstream_lock = [ordered]@{
    repo = $lockRepo
    ref = $lockRef
    commit = $lockCommit
    version = $lockVersion
  }
  official = [ordered]@{
    path = $officialFull
    remote = $officialRemote
    head = $officialHead
    status = $(if ($officialStatus) { "dirty_or_missing" } else { "clean" })
    remote_main = $remoteMain
    remote_delta = $(if ([string]::IsNullOrWhiteSpace($remoteMain)) { "unknown" } elseif ($remoteMain -eq $officialHead) { "none" } else { "update_available" })
  }
  versions = [ordered]@{
    target = Get-ProjectVersion -ProjectPath $targetFull
    staging = Get-ProjectVersion -ProjectPath $stagingFull
  }
  health = $health
  promotion_preflight = $preflight
  promotion_plan = $(if ($promotionPlan) { [ordered]@{ status = $promotionPlan.status; mode = $promotionPlan.mode; path = $promotionPlanPath } } else { $null })
  rollback_plan = $(if ($rollbackPlan) { [ordered]@{ status = $rollbackPlan.status; mode = $rollbackPlan.mode; path = $rollbackPlanPath } } else { $null })
}

Write-JsonRecord -Path $snapshotFull -Record $snapshot

Write-Host "Sub2API release snapshot"
Write-Host "  snapshot: $snapshotFull"
Write-Host "  git:      $head / origin $originHead"
Write-Host "  versions: target=$($snapshot.versions.target), staging=$($snapshot.versions.staging)"
Write-Host "  preflight: $($preflight.result)"
Write-Host "  upstream remote delta: $($snapshot.official.remote_delta)"
Write-Host "Snapshot result: PASS"
