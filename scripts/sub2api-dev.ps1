[CmdletBinding()]
param(
  [ValidateSet("status", "audit", "customization-check", "upstream-watch", "refresh", "preflight", "snapshot", "gate", "promote-dryrun", "rollback-dryrun", "push-preflight")]
  [string]$Action = "status",
  [string]$BackupPath = "",
  [switch]$CheckRemote,
  [switch]$SkipHttp,
  [switch]$Fast
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  $root = (& git rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
    throw "This script must run inside the codexapi git repository."
  }
  return [System.IO.Path]::GetFullPath($root.Trim())
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

function Invoke-Script {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [string[]]$Arguments = @()
  )
  $scriptPath = Join-Path $script:RepoRoot "scripts\$ScriptName"
  $powershellArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $scriptPath
  )
  $powershellArgs += $Arguments
  Invoke-Checked -FilePath "powershell" -Arguments $powershellArgs
}

$script:RepoRoot = Get-RepoRoot
Set-Location $script:RepoRoot

Write-Host "Sub2API dev entry"
Write-Host "Repo:   $script:RepoRoot"
Write-Host "Action: $Action"
Write-Host ""

switch ($Action) {
  "status" {
    $args = @()
    if ($CheckRemote) { $args += "-CheckRemote" }
    Invoke-Script -ScriptName "sub2api-status.ps1" -Arguments $args
  }
  "audit" {
    $args = @()
    if ($SkipHttp) { $args += "-SkipHttp" }
    Invoke-Script -ScriptName "sub2api-local-audit.ps1" -Arguments $args
  }
  "customization-check" {
    Invoke-Script -ScriptName "sub2api-customization-check.ps1"
  }
  "upstream-watch" {
    Invoke-Script -ScriptName "sub2api-upstream-watch.ps1"
  }
  "refresh" {
    $args = @("-RunAudit", "-RunCustomizationCheck", "-WriteReport", "-RunPreflight")
    if (-not $SkipHttp) { $args += "-CheckHttp" }
    if ($Fast) {
      $args += @("-SkipFrontendBuild", "-SkipBackendTest")
    }
    Invoke-Script -ScriptName "sub2api-refresh-upstream.ps1" -Arguments $args
  }
  "preflight" {
    Invoke-Script -ScriptName "sub2api-promotion-preflight.ps1"
  }
  "snapshot" {
    $args = @()
    if ($CheckRemote) { $args += "-CheckRemote" }
    if ($SkipHttp) { $args += "-SkipHttp" }
    Invoke-Script -ScriptName "sub2api-release-snapshot.ps1" -Arguments $args
  }
  "gate" {
    $args = @()
    if ($CheckRemote) { $args += "-CheckRemote" }
    if ($SkipHttp) { $args += "-SkipHttp" }
    Invoke-Script -ScriptName "sub2api-release-gate.ps1" -Arguments $args
  }
  "promote-dryrun" {
    Invoke-Script -ScriptName "sub2api-promote-staging.ps1"
  }
  "rollback-dryrun" {
    $args = @()
    if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
      $args += @("-BackupPath", $BackupPath)
    }
    Invoke-Script -ScriptName "sub2api-rollback-promotion.ps1" -Arguments $args
  }
  "push-preflight" {
    Invoke-Script -ScriptName "sub2api-push-preflight.ps1"
  }
}
