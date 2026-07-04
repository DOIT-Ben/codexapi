[CmdletBinding()]
param(
  [string]$Remote = "origin",
  [string]$Branch = "main",
  [string]$ExpectedRemoteUrl = "https://github.com/DOIT-Ben/codexapi.git"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  $root = (& git rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
    throw "This script must run inside the codexapi git repository."
  }
  return [System.IO.Path]::GetFullPath($root.Trim())
}

function Write-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Ok,
    [string]$Detail = ""
  )
  $status = if ($Ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1}{2}" -f $status, $Name, $(if ($Detail) { " - $Detail" } else { "" }))
  if (-not $Ok) {
    $script:PreflightFailed = $true
  }
}

function Test-AllowedPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [bool]$AllowPromotedSub2api = $false
  )
  $normalized = $Path.Replace("/", "\")
  return (
    $normalized -eq ".gitignore" -or
    $normalized -eq "AGENTS.md" -or
    ($AllowPromotedSub2api -and $normalized.StartsWith("sub2api\", [System.StringComparison]::OrdinalIgnoreCase)) -or
    $normalized.StartsWith("customizations\doit\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $normalized.StartsWith("docs\upstream-sync\", [System.StringComparison]::OrdinalIgnoreCase) -or
    ($normalized.StartsWith("scripts\", [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $normalized).StartsWith("sub2api-", [System.StringComparison]::OrdinalIgnoreCase))
  )
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

function Test-PromotedTargetState {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)
  $lockVersion = Get-UpstreamLockValue -LockPath (Join-Path $RepoRoot "customizations\doit\upstream.lock") -Name "upstream_version"
  $targetVersion = Get-ProjectVersion -ProjectPath (Join-Path $RepoRoot "sub2api")
  $promotionPlanPath = Join-Path $RepoRoot "workbench\upstream-sync\reports\sub2api-promotion-plan-latest.json"
  if (-not (Test-Path -LiteralPath $promotionPlanPath -PathType Leaf)) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "promotion plan missing"
    }
  }
  $promotionPlan = Get-Content -LiteralPath $promotionPlanPath -Raw | ConvertFrom-Json
  $ok =
    [string]$promotionPlan.status -eq "completed" -and
    [string]$promotionPlan.mode -eq "execute" -and
    -not [string]::IsNullOrWhiteSpace($lockVersion) -and
    $targetVersion -eq $lockVersion

  return [pscustomobject]@{
    Ok = $ok
    Detail = "target=$targetVersion, locked=$lockVersion, promotion=$($promotionPlan.status)"
  }
}

$script:PreflightFailed = $false
$repoRoot = Get-RepoRoot
Set-Location $repoRoot
$promotedTarget = Test-PromotedTargetState -RepoRoot $repoRoot

Write-Host "Sub2API push preflight"
Write-Host "Repo:   $repoRoot"
Write-Host "Remote: $Remote"
Write-Host "Branch: $Branch"
Write-Host ""

$remoteUrl = (& git remote get-url $Remote 2>$null).Trim()
Write-Check -Name "remote url" -Ok ($LASTEXITCODE -eq 0 -and $remoteUrl -eq $ExpectedRemoteUrl) -Detail $remoteUrl

$currentBranch = (& git branch --show-current 2>$null).Trim()
Write-Check -Name "current branch" -Ok ($LASTEXITCODE -eq 0 -and $currentBranch -eq $Branch) -Detail $currentBranch

$remoteRef = "refs/heads/$Branch"
$remoteLine = (& git ls-remote $Remote $remoteRef 2>$null)
$remoteCommit = ""
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteLine)) {
  $remoteCommit = ($remoteLine -split "\s+")[0]
}
Write-Check -Name "remote branch reachable" -Ok (-not [string]::IsNullOrWhiteSpace($remoteCommit)) -Detail $remoteCommit

$trackingRef = "$Remote/$Branch"
$trackingCommit = (& git rev-parse $trackingRef 2>$null).Trim()
Write-Check -Name "local tracking ref matches remote" -Ok ($LASTEXITCODE -eq 0 -and $trackingCommit -eq $remoteCommit) -Detail $trackingCommit

$ahead = [int]((& git rev-list --count "$trackingRef..HEAD").Trim())
$behind = [int]((& git rev-list --count "HEAD..$trackingRef").Trim())
Write-Check -Name "branch is ahead of remote" -Ok ($ahead -gt 0) -Detail "ahead=$ahead"
Write-Check -Name "branch is not behind remote" -Ok ($behind -eq 0) -Detail "behind=$behind"

$committedFiles = @(& git diff --name-only "$trackingRef..HEAD" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$committedSub2apiFiles = @($committedFiles | Where-Object { $_ -like "sub2api/*" })
Write-Check -Name "committed sub2api tree is promotion-backed" -Ok ($committedSub2apiFiles.Count -eq 0 -or $promotedTarget.Ok) -Detail $(if ($committedSub2apiFiles.Count -eq 0) { "no sub2api files" } else { $promotedTarget.Detail })

$unexpectedCommittedFiles = @($committedFiles | Where-Object { -not (Test-AllowedPath -Path $_ -AllowPromotedSub2api $promotedTarget.Ok) })
Write-Check -Name "committed files stay in expected sync roots" -Ok ($unexpectedCommittedFiles.Count -eq 0) -Detail $(if ($unexpectedCommittedFiles.Count) { $unexpectedCommittedFiles -join ", " } else { "all committed files allowed" })

$stagedFiles = @(& git diff --cached --name-only | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
Write-Check -Name "index has no staged leftovers" -Ok ($stagedFiles.Count -eq 0) -Detail "$($stagedFiles.Count) files"

$uncommittedFiles = @(& git diff --name-only | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$unexpectedUncommittedFiles = @($uncommittedFiles | Where-Object { $_ -notlike "sub2api/*" })
Write-Check -Name "remaining unstaged changes are only old sub2api diffs" -Ok ($unexpectedUncommittedFiles.Count -eq 0) -Detail "$($uncommittedFiles.Count) files"

$localAudit = Join-Path $repoRoot "scripts\sub2api-local-audit.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $localAudit
Write-Check -Name "local audit command" -Ok ($LASTEXITCODE -eq 0) -Detail "exit=$LASTEXITCODE"

if ($script:PreflightFailed) {
  Write-Host "Push preflight result: FAIL"
  exit 1
}

Write-Host "Push preflight result: READY_TO_PUSH_WITH_EXPLICIT_APPROVAL"
