param(
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$example = Join-Path $root ".env.example"
$envFile = Join-Path $root ".env"

if ((Test-Path $envFile) -and -not $Force) {
  Write-Host ".env already exists. Use -Force to overwrite." -ForegroundColor Yellow
  exit 0
}

function New-HexSecret([int]$Bytes = 32) {
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($buffer)
  } finally {
    $rng.Dispose()
  }
  return ($buffer | ForEach-Object { $_.ToString("x2") }) -join ""
}

function New-Password([int]$Bytes = 24) {
  return New-HexSecret $Bytes
}

$content = Get-Content $example -Raw
$content = $content.Replace("CHANGE_ME_ADMIN_PASSWORD", (New-Password 18))
$content = $content.Replace("CHANGE_ME_JWT_SECRET_HEX_32_BYTES", (New-HexSecret 32))
$content = $content.Replace("CHANGE_ME_TOTP_HEX_32_BYTES", (New-HexSecret 32))
$content = $content.Replace("CHANGE_ME_POSTGRES_PASSWORD", (New-Password 24))
$content = $content.Replace("CHANGE_ME_REDIS_PASSWORD", (New-Password 24))

Set-Content -Path $envFile -Value $content -Encoding UTF8

Write-Host "Created $envFile" -ForegroundColor Green
Write-Host "Local preview URL: http://localhost:18080"
Write-Host "Before production, edit SITE_ADDRESS, APP_BASE_URL, CORS_ALLOWED_ORIGINS, and ADMIN_EMAIL."
