[CmdletBinding()]
param(
  [switch]$SkipHttp,
  [string[]]$HealthUrls = @(
    "http://127.0.0.1:18082/health",
    "http://127.0.0.1:18083/health"
  )
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
    $script:AuditFailed = $true
  }
}

function Test-PowerShellSyntax {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Files)
  $failures = @()
  foreach ($file in $Files) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors -and $parseErrors.Count -gt 0) {
      $failures += [pscustomobject]@{
        File = $file.Name
        Count = $parseErrors.Count
      }
    }
  }
  return $failures
}

function Test-SensitiveValuePatterns {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Files)
  $pattern = [regex]'(?i)(password|secret|token|api[_-]?key)\s*[=:]\s*([^\s\}"'']+)'
  $hits = @()
  foreach ($file in $Files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $matches = $pattern.Matches($text)
    if ($matches.Count -gt 0) {
      $hits += [pscustomobject]@{
        File = $file.FullName.Substring($repoRoot.Length + 1)
        Count = $matches.Count
      }
    }
  }
  return $hits
}

function Test-HealthUrl {
  param([Parameter(Mandatory = $true)][string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8
    return [pscustomobject]@{
      Url = $Url
      Ok = $response.StatusCode -eq 200
      Detail = "status=$($response.StatusCode)"
    }
  } catch {
    return [pscustomobject]@{
      Url = $Url
      Ok = $false
      Detail = $_.Exception.Message
    }
  }
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

function Test-LocalDiffInventory {
  param([Parameter(Mandatory = $true)][string]$InventoryPath)
  $diffPaths = @(& git diff --name-only -- sub2api | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "git diff failed"
    }
  }
  if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "inventory missing"
    }
  }

  $inventoryText = Get-Content -LiteralPath $InventoryPath -Raw
  $missing = @()
  foreach ($path in $diffPaths) {
    $windowsPath = $path.Replace("/", "\")
    if (-not $inventoryText.Contains($windowsPath)) {
      $missing += $windowsPath
    }
  }

  if ($missing.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "missing: $($missing -join ', ')"
    }
  }

  return [pscustomobject]@{
    Ok = $true
    Detail = "$($diffPaths.Count)/$($diffPaths.Count)"
  }
}

function Test-UntrackedAssetScope {
  $statusLines = @(& git status --porcelain --untracked-files=all | Where-Object { $_.StartsWith("?? ") })
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "git status failed"
    }
  }

  $unexpected = @()
  foreach ($line in $statusLines) {
    $path = $line.Substring(3).Replace("/", "\")
    $isExpected =
      $path -eq "AGENTS.md" -or
      $path.StartsWith("customizations\doit\", [System.StringComparison]::OrdinalIgnoreCase) -or
      $path.StartsWith("docs\upstream-sync\", [System.StringComparison]::OrdinalIgnoreCase) -or
      ($path.StartsWith("scripts\", [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $path).StartsWith("sub2api-", [System.StringComparison]::OrdinalIgnoreCase))

    if (-not $isExpected) {
      $unexpected += $path
    }
  }

  if ($unexpected.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "unexpected: $($unexpected -join ', ')"
    }
  }

  return [pscustomobject]@{
    Ok = $true
    Detail = "$($statusLines.Count) untracked assets in expected roots"
  }
}

function Test-OfficialSourceState {
  param(
    [Parameter(Mandatory = $true)][string]$OfficialPath,
    [Parameter(Mandatory = $true)][string]$ExpectedRemote,
    [string]$ExpectedCommit = ""
  )
  if (-not (Test-Path -LiteralPath $OfficialPath -PathType Container)) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "official clone missing"
    }
  }

  $remote = (& git -C $OfficialPath remote get-url origin 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $remote -ne $ExpectedRemote) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "remote mismatch: $remote"
    }
  }

  $status = @(& git -C $OfficialPath status --porcelain 2>$null)
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "git status failed"
    }
  }
  if ($status.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "official clone dirty"
    }
  }

  $commit = (& git -C $OfficialPath rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "rev-parse failed"
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedCommit) -and $commit -ne $ExpectedCommit) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "commit mismatch: $commit"
    }
  }

  return [pscustomobject]@{
    Ok = $true
    Detail = "clean official clone at $commit"
  }
}

function Test-RequiredAssetPresence {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string[]]$RelativePaths
  )

  $missing = @()
  foreach ($relativePath in $RelativePaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath) -PathType Leaf)) {
      $missing += $relativePath
    }
  }

  if ($missing.Count -gt 0) {
    return [pscustomobject]@{
      Ok = $false
      Detail = "missing: $($missing -join ', ')"
    }
  }

  return [pscustomobject]@{
    Ok = $true
    Detail = "$($RelativePaths.Count)/$($RelativePaths.Count)"
  }
}

$script:AuditFailed = $false
$repoRoot = Get-RepoRoot
Set-Location $repoRoot
$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
$lockCommit = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_commit"
if ([string]::IsNullOrWhiteSpace($lockVersion)) {
  $lockVersion = "unknown"
}

Write-Host "Sub2API local audit"
Write-Host "Repo: $repoRoot"

$scriptFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts") -Filter "sub2api-*.ps1" -File)
$docFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs\upstream-sync") -File -ErrorAction SilentlyContinue)
$customFiles = @(
  Get-ChildItem -LiteralPath (Join-Path $repoRoot "customizations\doit") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch "\\overlays\\" -and
      $_.Extension -in @(".md", ".ps1", ".lock", ".yml", ".patch")
    }
)
$auditFiles = @($scriptFiles + $docFiles + $customFiles)

$syntaxFailures = Test-PowerShellSyntax -Files $scriptFiles
Write-Check -Name "PowerShell script syntax" -Ok ($syntaxFailures.Count -eq 0) -Detail $(if ($syntaxFailures.Count) { ($syntaxFailures | ConvertTo-Json -Compress) } else { "$($scriptFiles.Count) scripts parsed" })

$sensitiveHits = Test-SensitiveValuePatterns -Files $auditFiles
Write-Check -Name "sensitive value assignment patterns" -Ok ($sensitiveHits.Count -eq 0) -Detail $(if ($sensitiveHits.Count) { ($sensitiveHits | ConvertTo-Json -Compress) } else { "0 matches" })

$requiredAssets = @(
  "AGENTS.md",
  "scripts\sub2api-dev.ps1",
  "scripts\sub2api-local-audit.ps1",
  "scripts\sub2api-promote-staging.ps1",
  "scripts\sub2api-promotion-preflight.ps1",
  "scripts\sub2api-push-preflight.ps1",
  "scripts\sub2api-refresh-upstream.ps1",
  "scripts\sub2api-staging-compose.ps1",
  "scripts\sub2api-status.ps1",
  "scripts\sub2api-upstream-report.ps1",
  "scripts\sub2api-upstream-sync.ps1",
  "scripts\sub2api-verify-staging.ps1",
  "docs\upstream-sync\README.md",
  "docs\upstream-sync\2026-07-05-doit-local-diff-inventory.md",
  "docs\upstream-sync\2026-07-05-doit-promotion-runbook.md",
  "docs\upstream-sync\2026-07-05-doit-upstream-sync-design.md",
  "docs\upstream-sync\2026-07-05-doit-upstream-sync-implementation-plan.md",
  "docs\upstream-sync\2026-07-05-doit-upstream-sync-status.md",
  "customizations\doit\README.md",
  "customizations\doit\apply-doit-overlay.ps1",
  "customizations\doit\docker-compose.staging.yml",
  "customizations\doit\upstream.lock",
  "customizations\doit\overlays\frontend\src\components\layout\AppLayout.vue",
  "customizations\doit\overlays\frontend\src\components\layout\AuthLayout.vue",
  "customizations\doit\overlays\frontend\src\style.css",
  "customizations\doit\overlays\frontend\tailwind.config.js",
  "customizations\doit\patches\.gitkeep",
  "customizations\doit\patches\0002-doit-local-docker-build.patch",
  "customizations\doit\retired\.gitkeep",
  "customizations\doit\retired\0001-legacy-codex-import-shared-account.patch",
  "customizations\doit\retired\0002-old-version-branding-theme-diff.patch"
)
$requiredAssetsCheck = Test-RequiredAssetPresence -Root $repoRoot -RelativePaths $requiredAssets
Write-Check -Name "required upstream-sync assets are present" -Ok $requiredAssetsCheck.Ok -Detail $requiredAssetsCheck.Detail

$ignoredPaths = @(
  "sub2api-official",
  "workbench/upstream-sync",
  "workbench/upstream-sync/sub2api-doit-$lockVersion",
  "graphify-out/graph.json",
  "sub2api/backend/sub2api-new",
  "workbench/key-usage-dashboard-evidence.png",
  "workbench/image-test-response.json"
)
$ignoreOutput = (& git check-ignore -v @ignoredPaths 2>$null)
Write-Check -Name "generated/local artifact paths are git-ignored" -Ok ($LASTEXITCODE -eq 0 -and $ignoreOutput.Count -eq $ignoredPaths.Count) -Detail "$($ignoreOutput.Count)/$($ignoredPaths.Count)"

$inventoryPath = Join-Path $repoRoot "docs\upstream-sync\2026-07-05-doit-local-diff-inventory.md"
$inventoryCheck = Test-LocalDiffInventory -InventoryPath $inventoryPath
Write-Check -Name "local sub2api diffs are inventoried" -Ok $inventoryCheck.Ok -Detail $inventoryCheck.Detail

$untrackedScopeCheck = Test-UntrackedAssetScope
Write-Check -Name "visible untracked files are expected project assets" -Ok $untrackedScopeCheck.Ok -Detail $untrackedScopeCheck.Detail

$officialCheck = Test-OfficialSourceState -OfficialPath (Join-Path $repoRoot "sub2api-official") -ExpectedRemote "https://github.com/Wei-Shaw/sub2api.git" -ExpectedCommit $lockCommit
Write-Check -Name "official upstream clone is clean and locked" -Ok $officialCheck.Ok -Detail $officialCheck.Detail

if (-not $SkipHttp) {
  foreach ($url in $HealthUrls) {
    $health = Test-HealthUrl -Url $url
    Write-Check -Name "HTTP health $url" -Ok $health.Ok -Detail $health.Detail
  }
}

if ($script:AuditFailed) {
  Write-Host "Audit result: FAIL"
  exit 1
}

Write-Host "Audit result: PASS"
