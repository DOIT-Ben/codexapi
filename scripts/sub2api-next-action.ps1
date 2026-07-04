[CmdletBinding()]
param(
  [string]$WatchPath = ".\workbench\upstream-sync\reports\sub2api-upstream-watch-latest.json",
  [string]$GatePath = ".\workbench\upstream-sync\reports\sub2api-release-gate-latest.json",
  [string]$PromotionPlanPath = ".\workbench\upstream-sync\reports\sub2api-promotion-plan-latest.json",
  [string]$DecisionPath = ".\workbench\upstream-sync\reports\sub2api-next-action-latest.json",
  [switch]$RefreshEvidence
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
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FilePath $($Arguments -join ' ')"
  }
}

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

$watchFull = Resolve-PathFromRoot -Root $repoRoot -Path $WatchPath
$gateFull = Resolve-PathFromRoot -Root $repoRoot -Path $GatePath
$promotionPlanFull = Resolve-PathFromRoot -Root $repoRoot -Path $PromotionPlanPath
$decisionFull = Resolve-PathFromRoot -Root $repoRoot -Path $DecisionPath

if ($RefreshEvidence) {
  Invoke-Checked -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts\sub2api-upstream-watch.ps1"), "-WatchPath", $watchFull)
  Invoke-Checked -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts\sub2api-release-gate.ps1"), "-CheckRemote", "-GatePath", $gateFull)
  Invoke-Checked -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts\sub2api-promote-staging.ps1"), "-PlanPath", $promotionPlanFull)
}

$watch = Read-JsonFile -Path $watchFull
$gate = Read-JsonFile -Path $gateFull
$promotionPlan = Read-JsonFile -Path $promotionPlanFull

$action = "COLLECT_EVIDENCE"
$command = ".\scripts\sub2api-next-action.ps1 -RefreshEvidence"
$reason = "required evidence is missing"

if ($watch -and $watch.result -eq "UPDATE_AVAILABLE") {
  $action = "REFRESH_FROM_UPSTREAM"
  $command = ".\scripts\sub2api-dev.ps1 refresh"
  $reason = "official upstream has a newer commit"
} elseif ($gate -and $gate.result -ne "PASS") {
  $action = "FIX_RELEASE_GATE"
  $command = ".\scripts\sub2api-dev.ps1 gate -CheckRemote"
  $reason = "release gate is not passing"
} elseif ($gate -and $gate.result -eq "PASS" -and $promotionPlan -and $promotionPlan.checks.target_health.ok -eq $true) {
  $action = "READY_TO_PROMOTE_AFTER_STOP_TARGET"
  $command = "cd sub2api\deploy; docker compose -f docker-compose.local.yml down; cd ..\..; .\scripts\sub2api-promote-staging.ps1 -Execute"
  $reason = "release gate is passing, but target runtime is still reachable"
} elseif ($gate -and $gate.result -eq "PASS" -and $promotionPlan -and $promotionPlan.checks.target_health.ok -eq $false) {
  $action = "READY_TO_PROMOTE"
  $command = ".\scripts\sub2api-promote-staging.ps1 -Execute"
  $reason = "release gate is passing and target runtime is not reachable"
} elseif ($gate -and $gate.result -eq "PASS") {
  $action = "RUN_PROMOTION_DRYRUN"
  $command = ".\scripts\sub2api-dev.ps1 promote-dryrun"
  $reason = "release gate is passing but promotion plan evidence is missing"
}

$record = [ordered]@{
  schema = "doit.sub2api.next-action.v1"
  generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  action = $action
  command = $command
  reason = $reason
  evidence = [ordered]@{
    watch = $(if ($watch) { [ordered]@{ result = $watch.result; update_available = $watch.upstream.update_available; path = $watchFull } } else { $null })
    gate = $(if ($gate) { [ordered]@{ result = $gate.result; path = $gateFull } } else { $null })
    promotion_plan = $(if ($promotionPlan) { [ordered]@{ status = $promotionPlan.status; mode = $promotionPlan.mode; target_health = $promotionPlan.checks.target_health.ok; path = $promotionPlanFull } } else { $null })
  }
}

Write-JsonRecord -Path $decisionFull -Record $record

Write-Host "Sub2API next action"
Write-Host "  decision: $decisionFull"
Write-Host "  action:   $action"
Write-Host "  reason:   $reason"
Write-Host "  command:  $command"
