[CmdletBinding()]
param(
  [string]$TargetPath = ".\sub2api",
  [string]$StagingPath = "",
  [string]$ExpectedStagingVersion = "",
  [string]$ReportPath = "",
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
    return $null
  }
  return (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

function Test-HttpHealth {
  param([Parameter(Mandatory = $true)][string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8
    return [pscustomobject]@{
      Url = $Url
      Ok = $response.StatusCode -eq 200
      Status = $response.StatusCode
      Error = ""
    }
  } catch {
    return [pscustomobject]@{
      Url = $Url
      Ok = $false
      Status = 0
      Error = $_.Exception.Message
    }
  }
}

function Write-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Ok,
    [string]$Detail = ""
  )
  $status = if ($Ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1}{2}" -f $status, $Name, $(if ($Detail) { " - $Detail" } else { "" }))
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

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
if ([string]::IsNullOrWhiteSpace($ExpectedStagingVersion)) {
  $ExpectedStagingVersion = $lockVersion
}
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  if ([string]::IsNullOrWhiteSpace($ExpectedStagingVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$ExpectedStagingVersion"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = ".\workbench\upstream-sync\reports\sub2api-upstream-report-latest.md"
}

$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$reportFull = Resolve-PathFromRoot -Root $repoRoot -Path $ReportPath

$targetExists = Test-Path -LiteralPath $targetFull -PathType Container
$stagingExists = Test-Path -LiteralPath $stagingFull -PathType Container
$reportExists = Test-Path -LiteralPath $reportFull -PathType Leaf
$targetVersion = if ($targetExists) { Get-Version -ProjectPath $targetFull } else { $null }
$stagingVersion = if ($stagingExists) { Get-Version -ProjectPath $stagingFull } else { $null }

$targetHealth = Test-HttpHealth -Url $TargetHealthUrl
$stagingHealth = Test-HttpHealth -Url $StagingHealthUrl

$requiredStagingFiles = @(
  "backend\cmd\server\VERSION",
  "frontend\package.json",
  "deploy\Dockerfile",
  "deploy\docker-compose.local.yml"
)
$missingStagingFiles = @()
if ($stagingExists) {
  foreach ($relativePath in $requiredStagingFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $stagingFull $relativePath) -PathType Leaf)) {
      $missingStagingFiles += $relativePath
    }
  }
}

$runtimePaths = @(
  "deploy\.env",
  "deploy\data",
  "deploy\postgres_data",
  "deploy\redis_data"
)
$existingRuntimePaths = @()
if ($targetExists) {
  foreach ($relativePath in $runtimePaths) {
    if (Test-Path -LiteralPath (Join-Path $targetFull $relativePath)) {
      $existingRuntimePaths += $relativePath
    }
  }
}

$reportContent = if ($reportExists) { Get-Content -LiteralPath $reportFull -Raw } else { "" }
$reportChecks = @()
if ($reportExists) {
  if (-not [string]::IsNullOrWhiteSpace($targetVersion)) {
    $reportChecks += [pscustomobject]@{
      Name = "target_version"
      Ok = $reportContent.Contains("- target_version: $targetVersion")
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($stagingVersion)) {
    $reportChecks += [pscustomobject]@{
      Name = "staging_version"
      Ok = $reportContent.Contains("- staging_version: $stagingVersion")
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($lockCommit)) {
    $reportChecks += [pscustomobject]@{
      Name = "official_commit"
      Ok = $reportContent.Contains("- official_commit: $lockCommit")
    }
  }
}
$failedReportChecks = @($reportChecks | Where-Object { -not $_.Ok } | ForEach-Object { $_.Name })
$reportOk = $reportExists -and ($failedReportChecks.Count -eq 0)

Write-Host "Sub2API promotion preflight"
Write-Host "Repo:    $repoRoot"
Write-Host "Target:  $targetFull"
Write-Host "Staging: $stagingFull"
Write-Host "Report:  $reportFull"
Write-Host ""

Write-Check -Name "target project exists" -Ok $targetExists
Write-Check -Name "staging project exists" -Ok $stagingExists
Write-Check -Name "target version detected" -Ok (-not [string]::IsNullOrWhiteSpace($targetVersion)) -Detail $targetVersion
Write-Check -Name "staging version detected" -Ok (-not [string]::IsNullOrWhiteSpace($stagingVersion)) -Detail $stagingVersion
$versionOk = $targetVersion -ne $stagingVersion
if (-not [string]::IsNullOrWhiteSpace($ExpectedStagingVersion)) {
  $versionOk = $versionOk -and ($stagingVersion -eq $ExpectedStagingVersion)
}
Write-Check -Name "staging is newer than target" -Ok $versionOk -Detail "$targetVersion -> $stagingVersion"
Write-Check -Name "staging required files present" -Ok ($missingStagingFiles.Count -eq 0) -Detail $(if ($missingStagingFiles.Count) { $missingStagingFiles -join ", " } else { "all required files found" })
Write-Check -Name "target runtime paths detected" -Ok ($existingRuntimePaths.Count -gt 0) -Detail ($existingRuntimePaths -join ", ")
Write-Check -Name "upstream absorption report" -Ok $reportOk -Detail $(if ($reportExists) { if ($failedReportChecks.Count) { "stale fields: $($failedReportChecks -join ', ')" } else { "report matches current versions" } } else { "missing report" })
Write-Check -Name "target health endpoint" -Ok $targetHealth.Ok -Detail "$($targetHealth.Url) status=$($targetHealth.Status)"
Write-Check -Name "staging health endpoint" -Ok $stagingHealth.Ok -Detail "$($stagingHealth.Url) status=$($stagingHealth.Status)"

Write-Host ""
if (
  $targetExists -and
  $stagingExists -and
  -not [string]::IsNullOrWhiteSpace($targetVersion) -and
  -not [string]::IsNullOrWhiteSpace($stagingVersion) -and
  $missingStagingFiles.Count -eq 0 -and
  $reportOk -and
  $targetHealth.Ok -and
  $stagingHealth.Ok
) {
  Write-Host "Preflight result: READY_FOR_EXPLICIT_PROMOTION_APPROVAL"
  exit 0
}

Write-Host "Preflight result: NOT_READY"
exit 1
