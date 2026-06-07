Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
  throw "Missing .env. Run .\scripts\init-secrets.ps1 first."
}

docker compose --env-file .env config --quiet
docker compose --env-file .env up -d

$healthUrl = "http://localhost:18080/health"
$deadline = (Get-Date).AddMinutes(3)
$ok = $false
while ((Get-Date) -lt $deadline) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 5
    if ($resp.StatusCode -eq 200) {
      $ok = $true
      break
    }
  } catch {
    Start-Sleep -Seconds 5
  }
}

docker compose --env-file .env ps

if (-not $ok) {
  docker compose --env-file .env logs --tail 80 sub2api
  throw "Health check failed: $healthUrl"
}

Write-Host "OK: local deployment is healthy at http://localhost:18080" -ForegroundColor Green
