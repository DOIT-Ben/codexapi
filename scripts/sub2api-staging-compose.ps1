[CmdletBinding()]
param(
  [ValidateSet("status", "health", "build", "up", "down", "restart")]
  [string]$Action = "status",
  [string]$StagingPath = "",
  [string]$ImageTag = "",
  [string]$ProjectName = "sub2api-doit-staging",
  [string]$HealthUrl = "http://127.0.0.1:18083/health"
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

function New-HexString {
  param([int]$Bytes = 32)
  $buffer = [byte[]]::new($Bytes)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
  return -join ($buffer | ForEach-Object { $_.ToString("x2") })
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

function Ensure-StagingFiles {
  $overridePath = Join-Path $deployFull ".doit-staging.override.yml"
  $envPath = Join-Path $deployFull ".env.staging"

  if (-not (Test-Path -LiteralPath $overridePath -PathType Leaf)) {
    @"
services:
  sub2api:
    image: ${ImageTag}
    container_name: sub2api-doit-staging
    ports:
      - "127.0.0.1:18083:8080"
    volumes:
      - ./staging_data:/app/data:Z

  postgres:
    container_name: sub2api-doit-staging-postgres
    volumes:
      - ./staging_postgres_data:/var/lib/postgresql/data:Z

  redis:
    container_name: sub2api-doit-staging-redis
    volumes:
      - ./staging_redis_data:/data:Z
"@ | Set-Content -LiteralPath $overridePath -Encoding utf8
  }

  if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    $jwtValue = New-HexString -Bytes 32
    $totpValue = New-HexString -Bytes 32
    $pgValue = New-HexString -Bytes 24
    $adminValue = New-HexString -Bytes 18
    $envLines = @(
      "BIND_HOST=127.0.0.1",
      "SERVER_PORT=18083",
      ("POSTGRES_" + "PASSWORD" + "={0}" -f $pgValue),
      "ADMIN_EMAIL=admin@doit.local",
      ("ADMIN_" + "PASSWORD" + "={0}" -f $adminValue),
      ("JWT_" + "SECRET" + "={0}" -f $jwtValue),
      ("TOTP_ENCRYPTION_" + "KEY" + "={0}" -f $totpValue)
    )
    $envLines | Set-Content -LiteralPath $envPath -Encoding utf8
  }

  return [pscustomobject]@{
    OverridePath = $overridePath
    EnvPath = $envPath
  }
}

function Invoke-StagingCompose {
  param(
    [Parameter(Mandatory = $true)][string[]]$ComposeArgs
  )
  $files = Ensure-StagingFiles
  $args = @(
    "compose",
    "--env-file", $files.EnvPath,
    "-p", $ProjectName,
    "-f", (Join-Path $deployFull "docker-compose.local.yml"),
    "-f", $files.OverridePath
  ) + $ComposeArgs
  Invoke-Checked -FilePath "docker" -Arguments $args -WorkingDirectory $deployFull
}

function Test-Health {
  try {
    $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 8
    Write-Host "Health: $HealthUrl status=$($response.StatusCode)"
    if ($response.StatusCode -ne 200) {
      exit 1
    }
  } catch {
    Write-Host "Health: $HealthUrl error=$($_.Exception.Message)"
    exit 1
  }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$lockPath = Join-Path $repoRoot "customizations\doit\upstream.lock"
$lockVersion = Get-UpstreamLockValue -LockPath $lockPath -Name "upstream_version"
if ([string]::IsNullOrWhiteSpace($StagingPath)) {
  if ([string]::IsNullOrWhiteSpace($lockVersion)) {
    throw "StagingPath was not provided and upstream_version was not found in $lockPath"
  }
  $StagingPath = ".\workbench\upstream-sync\sub2api-doit-$lockVersion"
}
if ([string]::IsNullOrWhiteSpace($ImageTag)) {
  if ([string]::IsNullOrWhiteSpace($lockVersion)) {
    throw "ImageTag was not provided and upstream_version was not found in $lockPath"
  }
  $ImageTag = "sub2api-doit:$lockVersion-staging"
}

$stagingFull = Resolve-PathFromRoot -Root $repoRoot -Path $StagingPath
$deployFull = Join-Path $stagingFull "deploy"

if (-not (Test-Path -LiteralPath (Join-Path $deployFull "docker-compose.local.yml") -PathType Leaf)) {
  throw "Staging deploy compose not found: $deployFull"
}

switch ($Action) {
  "status" {
    & docker ps --filter "name=sub2api-doit-staging" --format "{{.Names}}`t{{.Status}}`t{{.Ports}}"
    if ($LASTEXITCODE -ne 0) {
      throw "docker ps failed"
    }
  }
  "health" {
    Test-Health
  }
  "build" {
    Invoke-Checked -FilePath "docker" -Arguments @("build", "-f", "deploy\Dockerfile", "-t", $ImageTag, ".") -WorkingDirectory $stagingFull
  }
  "up" {
    Invoke-StagingCompose -ComposeArgs @("up", "-d")
  }
  "down" {
    Invoke-StagingCompose -ComposeArgs @("down")
  }
  "restart" {
    Invoke-StagingCompose -ComposeArgs @("up", "-d", "--force-recreate")
  }
}
