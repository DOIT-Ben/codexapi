[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$TargetPath = ".\sub2api",
  [string]$StagingRoot = ".\workbench\upstream-sync",
  [string[]]$HealthUrls = @(
    "target=http://127.0.0.1:18082/health",
    "staging=http://127.0.0.1:18083/health"
  ),
  [switch]$CheckRemote
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
    return "missing"
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
    return "status=$($response.StatusCode)"
  } catch {
    return "unreachable: $($_.Exception.Message)"
  }
}

function Get-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )
  return [System.IO.Path]::GetRelativePath($Root, $Path).Replace("/", "\")
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockRepo = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_repo"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($lockVersion)) {
  $lockVersion = "unknown"
}

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path (Join-Path $StagingRoot ("sub2api-doit-{0}" -f $lockVersion))

$branch = (& git branch --show-current).Trim()
$repoStatus = @(& git status --porcelain)
$sub2apiDiffs = @(& git diff --name-only -- sub2api | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$head = (& git rev-parse HEAD).Trim()
$originHead = (& git rev-parse origin/main 2>$null)
if ($LASTEXITCODE -ne 0) {
  $originHead = ""
} else {
  $originHead = ($originHead -join "`n").Trim()
}

Write-Host "Sub2API development status"
Write-Host "Repo:    $repoRoot"
Write-Host "Branch:  $branch"
Write-Host "HEAD:    $head"
Write-Host "Origin:  $originHead"
Write-Host "Changes: $($repoStatus.Count) working tree entries; $($sub2apiDiffs.Count) current sub2api diffs"
Write-Host ""

Write-Host "Upstream lock"
Write-Host "  repo:    $lockRepo"
Write-Host "  version: $lockVersion"
Write-Host "  commit:  $lockCommit"
Write-Host ""

Write-Host "Project versions"
Write-Host "  target:  $(Get-ProjectVersion -ProjectPath $targetFull) ($([System.IO.Path]::GetRelativePath($repoRoot, $targetFull)))"
Write-Host "  staging: $(Get-ProjectVersion -ProjectPath $stagingFull) ($([System.IO.Path]::GetRelativePath($repoRoot, $stagingFull)))"
Write-Host ""

Write-Host "Official clone"
if (Test-Path -LiteralPath $officialFull -PathType Container) {
  $officialRemote = Get-GitValue -WorkingDirectory $officialFull -Arguments @("remote", "get-url", "origin")
  $officialHead = Get-GitValue -WorkingDirectory $officialFull -Arguments @("rev-parse", "HEAD")
  $officialStatus = Get-GitValue -WorkingDirectory $officialFull -Arguments @("status", "--porcelain")
  Write-Host "  path:    $(Get-RelativePath -Root $repoRoot -Path $officialFull)"
  Write-Host "  remote:  $officialRemote"
  Write-Host "  head:    $officialHead"
  Write-Host "  status:  $(if ($officialStatus) { "dirty" } else { "clean" })"
  if ($CheckRemote) {
    $remoteLine = (& git ls-remote $officialRemote refs/heads/main 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remoteLine) {
      $remoteCommit = (($remoteLine -join "`n") -split "\s+")[0]
      Write-Host "  remote main: $remoteCommit"
      Write-Host "  remote delta: $(if ($remoteCommit -eq $officialHead) { "none" } else { "update available" })"
    } else {
      Write-Host "  remote main: unavailable"
    }
  }
} else {
  Write-Host "  missing: $(Get-RelativePath -Root $repoRoot -Path $officialFull)"
}
Write-Host ""

Write-Host "Health"
foreach ($entry in $HealthUrls) {
  $parts = $entry.Split("=", 2)
  if ($parts.Count -eq 2) {
    Write-Host "  $($parts[0]): $($parts[1]) $(Test-HealthUrl -Url $parts[1])"
  } else {
    Write-Host "  $entry $(Test-HealthUrl -Url $entry)"
  }
}
Write-Host ""

Write-Host "Next safe commands"
Write-Host "  refresh:   .\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -WriteReport -RunPreflight"
Write-Host "  audit:     .\scripts\sub2api-local-audit.ps1"
Write-Host "  preflight: .\scripts\sub2api-promotion-preflight.ps1"
