[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$WatchPath = ".\workbench\upstream-sync\reports\sub2api-upstream-watch-latest.json"
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

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockRepo = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_repo"
$lockRef = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_ref"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($lockRef)) {
  $lockRef = "main"
}
if ([string]::IsNullOrWhiteSpace($lockRepo)) {
  throw "upstream_repo was not found in $lockPath"
}

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$watchFull = Resolve-PathFromRoot -Root $repoRoot -Path $WatchPath

$officialHead = ""
$officialStatus = "missing"
$officialRemote = ""
if (Test-Path -LiteralPath $officialFull -PathType Container) {
  $officialHead = Get-GitValue -WorkingDirectory $officialFull -Arguments @("rev-parse", "HEAD")
  $officialRemote = Get-GitValue -WorkingDirectory $officialFull -Arguments @("remote", "get-url", "origin")
  $officialDirty = Get-GitValue -WorkingDirectory $officialFull -Arguments @("status", "--porcelain")
  $officialStatus = if ($officialDirty) { "dirty" } else { "clean" }
}

$remoteLine = (& git ls-remote $lockRepo "refs/heads/$lockRef" 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $remoteLine) {
  $record = [ordered]@{
    schema = "doit.sub2api.upstream-watch.v1"
    generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    result = "ERROR"
    error = "remote ref unavailable"
    upstream = [ordered]@{
      repo = $lockRepo
      ref = $lockRef
      locked_commit = $lockCommit
      locked_version = $lockVersion
    }
    official_clone = [ordered]@{
      path = $officialFull
      remote = $officialRemote
      head = $officialHead
      status = $officialStatus
    }
  }
  Write-JsonRecord -Path $watchFull -Record $record
  Write-Host "Sub2API upstream watch"
  Write-Host "  watch:  $watchFull"
  Write-Host "  result: ERROR"
  throw "Unable to read upstream remote ref $lockRepo refs/heads/$lockRef"
}

$remoteCommit = (($remoteLine -join "`n") -split "\s+")[0]
$updateAvailable = (-not [string]::IsNullOrWhiteSpace($lockCommit) -and $remoteCommit -ne $lockCommit)
$officialAtRemote = (-not [string]::IsNullOrWhiteSpace($officialHead) -and $officialHead -eq $remoteCommit)
$result = if ($updateAvailable) { "UPDATE_AVAILABLE" } else { "NO_UPDATE" }
$recommendedAction = if ($updateAvailable) {
  ".\scripts\sub2api-dev.ps1 refresh"
} else {
  "no action"
}

$record = [ordered]@{
  schema = "doit.sub2api.upstream-watch.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = $result
  upstream = [ordered]@{
    repo = $lockRepo
    ref = $lockRef
    locked_commit = $lockCommit
    locked_version = $lockVersion
    remote_commit = $remoteCommit
    update_available = [bool]$updateAvailable
  }
  official_clone = [ordered]@{
    path = $officialFull
    remote = $officialRemote
    head = $officialHead
    status = $officialStatus
    at_remote_commit = [bool]$officialAtRemote
  }
  recommended_action = $recommendedAction
}

Write-JsonRecord -Path $watchFull -Record $record

Write-Host "Sub2API upstream watch"
Write-Host "  watch:          $watchFull"
Write-Host "  locked commit:  $lockCommit"
Write-Host "  remote commit:  $remoteCommit"
Write-Host "  official clone: $officialStatus $officialHead"
Write-Host "  result:         $result"
Write-Host "  next:           $recommendedAction"
