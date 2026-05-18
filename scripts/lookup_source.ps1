# Look up default source_name for a tenant
# Usage: $src = & .\lookup_source.ps1 -Jwt $jwt -CompanyId 34329
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)][int]$CompanyId,
  [string]$Base = 'https://app.8vance.com'
)
$h = @{ Authorization = "Bearer $Jwt" }
$res = Invoke-RestMethod -Method Get -Uri "$Base/public/v1/company/$CompanyId/sources/" -Headers $h
$default = $res | Where-Object { $_.is_default } | Select-Object -First 1
if (-not $default) { $default = $res | Select-Object -First 1 }
return $default.source.name
