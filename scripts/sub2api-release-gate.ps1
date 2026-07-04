[CmdletBinding()]
param(
  [string]$SnapshotPath = ".\workbench\upstream-sync\reports\sub2api-release-snapshot-latest.json",
  [string]$GatePath = ".\workbench\upstream-sync\reports\sub2api-release-gate-latest.json",
  [switch]$CheckRemote,
  [switch]$SkipHttp,
  [switch]$SkipAudit,
  [switch]$SkipCustomizationCheck,
  [switch]$AllowUnsyncedGit,
  [switch]$AllowUpstreamDelta
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

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $previousNativePreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousNativePreference
  return [ordered]@{
    exit_code = $exitCode
    output = $output
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

function Add-GateCheck {
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

$snapshotFull = Resolve-PathFromRoot -Root $repoRoot -Path $SnapshotPath
$gateFull = Resolve-PathFromRoot -Root $repoRoot -Path $GatePath

$auditCapture = [ordered]@{
  skipped = [bool]$SkipAudit
  exit_code = $null
}
if (-not $SkipAudit) {
  $audit = Invoke-Capture -FilePath "powershell" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $repoRoot "scripts\sub2api-local-audit.ps1")
  )
  $auditCapture["exit_code"] = $audit.exit_code
}

$customizationCapture = [ordered]@{
  skipped = [bool]$SkipCustomizationCheck
  exit_code = $null
}
if (-not $SkipCustomizationCheck) {
  $customization = Invoke-Capture -FilePath "powershell" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $repoRoot "scripts\sub2api-customization-check.ps1")
  )
  $customizationCapture["exit_code"] = $customization.exit_code
}

$snapshotArgs = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  (Join-Path $repoRoot "scripts\sub2api-release-snapshot.ps1"),
  "-SnapshotPath",
  $snapshotFull
)
if ($CheckRemote) { $snapshotArgs += "-CheckRemote" }
if ($SkipHttp) { $snapshotArgs += "-SkipHttp" }
$snapshotCapture = Invoke-Capture -FilePath "powershell" -Arguments $snapshotArgs
if ($snapshotCapture.exit_code -ne 0) {
  $record = [ordered]@{
    schema = "doit.sub2api.release-gate.v1"
    generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    result = "FAIL"
    failure = "snapshot command failed"
    audit = $auditCapture
    snapshot = [ordered]@{
      path = $snapshotFull
      exit_code = $snapshotCapture.exit_code
    }
    checks = @()
  }
  Write-JsonRecord -Path $gateFull -Record $record
  Write-Host "Release gate result: FAIL"
  throw "Release snapshot command failed."
}

$snapshot = Get-Content -LiteralPath $snapshotFull -Raw | ConvertFrom-Json
$checks = New-Object System.Collections.Generic.List[object]

Add-GateCheck -Checks $checks -Name "local audit" -Ok ($SkipAudit -or $auditCapture.exit_code -eq 0) -Detail $(if ($SkipAudit) { "skipped" } else { "exit=$($auditCapture.exit_code)" })
Add-GateCheck -Checks $checks -Name "customization check" -Ok ($SkipCustomizationCheck -or $customizationCapture.exit_code -eq 0) -Detail $(if ($SkipCustomizationCheck) { "skipped" } else { "exit=$($customizationCapture.exit_code)" })
Add-GateCheck -Checks $checks -Name "git synced with origin" -Ok ($AllowUnsyncedGit -or [bool]$snapshot.git.synced_with_origin) -Detail "head=$($snapshot.git.head), origin=$($snapshot.git.origin_main)"
Add-GateCheck -Checks $checks -Name "official upstream clean" -Ok ($snapshot.official.status -eq "clean") -Detail $snapshot.official.status
Add-GateCheck -Checks $checks -Name "official remote delta" -Ok ($AllowUpstreamDelta -or $snapshot.official.remote_delta -eq "none" -or $snapshot.official.remote_delta -eq "unknown") -Detail $snapshot.official.remote_delta
Add-GateCheck -Checks $checks -Name "target version detected" -Ok (-not [string]::IsNullOrWhiteSpace([string]$snapshot.versions.target)) -Detail ([string]$snapshot.versions.target)
Add-GateCheck -Checks $checks -Name "staging version detected" -Ok (-not [string]::IsNullOrWhiteSpace([string]$snapshot.versions.staging)) -Detail ([string]$snapshot.versions.staging)
Add-GateCheck -Checks $checks -Name "staging differs from target" -Ok ([string]$snapshot.versions.target -ne [string]$snapshot.versions.staging) -Detail "$($snapshot.versions.target) -> $($snapshot.versions.staging)"
if (-not $SkipHttp) {
  Add-GateCheck -Checks $checks -Name "target health" -Ok ([bool]$snapshot.health.target.ok) -Detail "status=$($snapshot.health.target.status)"
  Add-GateCheck -Checks $checks -Name "staging health" -Ok ([bool]$snapshot.health.staging.ok) -Detail "status=$($snapshot.health.staging.status)"
}
Add-GateCheck -Checks $checks -Name "promotion preflight ready" -Ok ($snapshot.promotion_preflight.exit_code -eq 0 -and [string]$snapshot.promotion_preflight.result -eq "Preflight result: READY_FOR_EXPLICIT_PROMOTION_APPROVAL") -Detail ([string]$snapshot.promotion_preflight.result)

$failed = @($checks | Where-Object { -not $_.ok })
$result = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$record = [ordered]@{
  schema = "doit.sub2api.release-gate.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = $result
  audit = $auditCapture
  customization = $customizationCapture
  snapshot = [ordered]@{
    path = $snapshotFull
    exit_code = $snapshotCapture.exit_code
  }
  checks = $checks.ToArray()
}
Write-JsonRecord -Path $gateFull -Record $record

Write-Host "Sub2API release gate"
Write-Host "  snapshot: $snapshotFull"
Write-Host "  gate:     $gateFull"
foreach ($check in $checks) {
  $status = if ($check.ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1} - {2}" -f $status, $check.name, $check.detail)
}
Write-Host "Release gate result: $result"

if ($result -ne "PASS") {
  exit 1
}
