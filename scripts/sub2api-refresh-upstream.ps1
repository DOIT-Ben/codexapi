[CmdletBinding()]
param(
  [string]$OfficialPath = ".\sub2api-official",
  [string]$StagingRoot = ".\workbench\upstream-sync",
  [string]$TargetPath = ".\sub2api",
  [string]$ManifestPath = ".\customizations\doit\manifest.json",
  [switch]$SkipFetch,
  [switch]$SkipSync,
  [switch]$SkipVerify,
  [switch]$SkipFrontendBuild,
  [switch]$SkipBackendTest,
  [switch]$CheckHttp,
  [switch]$RunCustomizationCheck,
  [switch]$RunPreflight,
  [switch]$RunAudit,
  [switch]$WriteReport,
  [string]$ReportPath = ""
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

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$WorkingDirectory
  )
  if ($WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
      & $FilePath @Arguments
    } finally {
      Pop-Location
    }
  } else {
    & $FilePath @Arguments
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FilePath $($Arguments -join ' ')"
  }
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Lines
  )
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$officialFull = Resolve-PathFromRoot -Root $repoRoot -Path $OfficialPath
$stagingRootFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingRoot
$targetFull = Resolve-PathFromRoot -Root $repoRoot -Path $TargetPath
$manifestFull = Resolve-PathFromRoot -Root $repoRoot -Path $ManifestPath

if (-not (Test-Path -LiteralPath $officialFull -PathType Container)) {
  throw "Official source not found: $officialFull"
}
if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) {
  throw "Doit manifest not found: $manifestFull"
}
$manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json

if (-not $SkipFetch) {
  $officialStatus = (& git -C $officialFull status --porcelain)
  if (-not [string]::IsNullOrWhiteSpace(($officialStatus -join ""))) {
    throw "Official source has local changes. Refusing to fetch into a dirty upstream clone."
  }
  Invoke-Checked -FilePath "git" -Arguments @("-C", $officialFull, "fetch", "origin", "main", "--tags", "--prune")
  Invoke-Checked -FilePath "git" -Arguments @("-C", $officialFull, "checkout", "main")
  Invoke-Checked -FilePath "git" -Arguments @("-C", $officialFull, "merge", "--ff-only", "origin/main")
}

$upstreamCommit = (& git -C $officialFull rev-parse HEAD).Trim()
$upstreamVersion = (Get-Content -LiteralPath (Join-Path $officialFull "backend\cmd\server\VERSION") -Raw).Trim()
$stagingPath = Join-Path $stagingRootFull ("sub2api-doit-{0}" -f $upstreamVersion)

Write-Host "Upstream commit:  $upstreamCommit"
Write-Host "Upstream version: $upstreamVersion"
Write-Host "Staging path:     $stagingPath"

if (-not $SkipSync) {
  Invoke-Checked -FilePath "powershell" -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-upstream-sync.ps1"),
    "-OfficialPath", $officialFull,
    "-StagingPath", $stagingPath,
    "-ManifestPath", $manifestFull,
    "-Force"
  )
}

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
Write-Utf8NoBom -Path $lockPath -Lines @(
  "upstream_repo=https://github.com/Wei-Shaw/sub2api.git",
  "upstream_ref=main",
  "upstream_commit=$upstreamCommit",
  "upstream_version=$upstreamVersion",
  ("generated_at={0}" -f (Get-Date -Format "yyyy-MM-dd")),
  ("active_overlay={0}" -f $manifest.overlayScript),
  ("active_patches={0}" -f (@($manifest.activePatches) -join ",")),
  ("retired_patches={0}" -f (@($manifest.retiredPatches) -join ","))
)

if (-not $SkipVerify) {
  $verifyArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-verify-staging.ps1"),
    "-StagingPath", $stagingPath,
    "-ExpectedVersion", $upstreamVersion
  )
  if ($SkipFrontendBuild) { $verifyArgs += "-SkipFrontendBuild" }
  if ($SkipBackendTest) { $verifyArgs += "-SkipBackendTest" }
  if ($CheckHttp) { $verifyArgs += "-CheckHttp" }
  Invoke-Checked -FilePath "powershell" -Arguments $verifyArgs
}

if ($RunAudit) {
  $auditArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-local-audit.ps1")
  )
  if (-not $CheckHttp) { $auditArgs += "-SkipHttp" }
  Invoke-Checked -FilePath "powershell" -Arguments $auditArgs
}

if ($RunCustomizationCheck) {
  Invoke-Checked -FilePath "powershell" -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-customization-check.ps1"),
    "-ManifestPath", $manifestFull,
    "-StagingPath", $stagingPath
  )
}

if ($WriteReport) {
  if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $stagingRootFull "reports\sub2api-upstream-report-latest.md"
  }
  $reportArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-upstream-report.ps1"),
    "-OfficialPath", $officialFull,
    "-TargetPath", $targetFull,
    "-StagingPath", $stagingPath,
    "-ManifestPath", $manifestFull,
    "-ReportPath", $ReportPath
  )
  if ($CheckHttp) { $reportArgs += "-CheckHttp" }
  Invoke-Checked -FilePath "powershell" -Arguments $reportArgs
}

if ($RunPreflight) {
  Invoke-Checked -FilePath "powershell" -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoRoot "scripts\sub2api-promotion-preflight.ps1"),
    "-TargetPath", $targetFull,
    "-StagingPath", $stagingPath,
    "-ExpectedStagingVersion", $upstreamVersion
  )
}

Write-Host "Refresh result: PASS"
