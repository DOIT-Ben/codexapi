[CmdletBinding()]
param(
  [string]$StagingPath = "",
  [string]$ExpectedVersion = "",
  [string]$ExpectedBrand = "Doit API",
  [string]$GoImage = "golang:1.26.4-alpine",
  [string]$StagingHealthUrl = "http://127.0.0.1:18083/health",
  [switch]$SkipFrontendBuild,
  [switch]$SkipBackendTest,
  [switch]$CheckHttp
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

function Write-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Ok,
    [string]$Detail = ""
  )
  $status = if ($Ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1}{2}" -f $status, $Name, $(if ($Detail) { " - $Detail" } else { "" }))
  if (-not $Ok) {
    throw "Verification failed: $Name"
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

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($ExpectedVersion)) {
  $ExpectedVersion = $lockVersion
}
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  if ([string]::IsNullOrWhiteSpace($ExpectedVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$ExpectedVersion"
}

$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
Write-Host "Sub2API staging verification"
Write-Host "Staging: $stagingFull"

Write-Check -Name "staging directory exists" -Ok (Test-Path -LiteralPath $stagingFull -PathType Container)

$versionPath = Join-Path $stagingFull "backend\cmd\server\VERSION"
Write-Check -Name "version file exists" -Ok (Test-Path -LiteralPath $versionPath -PathType Leaf)
$version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
Write-Check -Name "expected version" -Ok ($version -eq $ExpectedVersion) -Detail $version

$brandFiles = @(
  "frontend\src\i18n\locales\en.ts",
  "frontend\src\i18n\locales\zh.ts",
  "frontend\src\components\layout\AuthLayout.vue"
)
$brandHits = 0
$legacyHits = 0
foreach ($relativePath in $brandFiles) {
  $path = Join-Path $stagingFull $relativePath
  Write-Check -Name "brand file exists: $relativePath" -Ok (Test-Path -LiteralPath $path -PathType Leaf)
  $content = [System.IO.File]::ReadAllText($path)
  if ($content.Contains($ExpectedBrand)) {
    $brandHits++
  }
  if ($content.Contains("Sub2API")) {
    $legacyHits++
  }
}
Write-Check -Name "expected brand is present" -Ok ($brandHits -eq $brandFiles.Count) -Detail "$brandHits/$($brandFiles.Count)"
Write-Check -Name "legacy brand removed from primary brand files" -Ok ($legacyHits -eq 0)

$themePath = Join-Path $stagingFull "frontend\tailwind.config.js"
Write-Check -Name "theme file exists" -Ok (Test-Path -LiteralPath $themePath -PathType Leaf)
$themeContent = [System.IO.File]::ReadAllText($themePath)
Write-Check -Name "Doit theme colors present" -Ok ($themeContent.Contains("#2f8f5b") -and $themeContent.Contains("#9a7b66"))

if (-not $SkipBackendTest) {
  $dockerPath = (Get-Command docker -ErrorAction SilentlyContinue).Source
  Write-Check -Name "docker command available for backend test" -Ok (-not [string]::IsNullOrWhiteSpace($dockerPath)) -Detail $dockerPath
  $dockerMount = "${stagingFull}:/src"
  Invoke-Checked -FilePath "docker" -Arguments @(
    "run", "--rm",
    "-v", $dockerMount,
    "-w", "/src/backend",
    $GoImage,
    "sh", "-c", "go test ./internal/handler/admin -run Codex -count=1"
  )
  Write-Check -Name "backend Codex focused tests" -Ok $true
}

if (-not $SkipFrontendBuild) {
  $pnpmPath = (Get-Command pnpm -ErrorAction SilentlyContinue).Source
  Write-Check -Name "pnpm command available" -Ok (-not [string]::IsNullOrWhiteSpace($pnpmPath)) -Detail $pnpmPath
  $frontendPath = Join-Path $stagingFull "frontend"
  Invoke-Checked -FilePath "pnpm" -Arguments @("install", "--frozen-lockfile") -WorkingDirectory $frontendPath
  Invoke-Checked -FilePath "pnpm" -Arguments @("run", "build") -WorkingDirectory $frontendPath
  Write-Check -Name "frontend production build" -Ok $true
}

if ($CheckHttp) {
  try {
    $response = Invoke-WebRequest -Uri $StagingHealthUrl -UseBasicParsing -TimeoutSec 8
    Write-Check -Name "staging health endpoint" -Ok ($response.StatusCode -eq 200) -Detail "$StagingHealthUrl status=$($response.StatusCode)"
  } catch {
    Write-Check -Name "staging health endpoint" -Ok $false -Detail $_.Exception.Message
  }
}

Write-Host "Verification result: PASS"
