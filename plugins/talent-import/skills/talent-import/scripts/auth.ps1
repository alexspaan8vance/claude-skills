# Auth helper - returns JWT access token for 8vance prod
# Usage: $jwt = & .\auth.ps1 -ClientId "..." -ClientSecret "..."
param(
  [Parameter(Mandatory=$true)][string]$ClientId,
  [Parameter(Mandatory=$true)][string]$ClientSecret,
  [string]$Base = 'https://app.8vance.com'
)
$body = '{"client_id":"' + $ClientId + '","client_secret":"' + $ClientSecret + '"}'
$r = Invoke-RestMethod -Method Post -Uri "$Base/public/v1/auth/token/client/" -ContentType 'application/json' -Body $body
if (-not $r.access -or $r.access.Length -lt 100) { throw 'JWT empty or too short - check credentials' }
return $r.access
