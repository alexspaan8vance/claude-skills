# Fetch full vacancy detail + skills
# Usage: $job = & .\fetch_job.ps1 -Jwt $jwt -JobId 1046188143
# Returns hashtable: {detail, skills}
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)][long]$JobId,
  [string]$Base = 'https://app.8vance.com'
)
$h = @{ Authorization = "Bearer $Jwt" }
$detail = Invoke-RestMethod -Method Get -Uri "$Base/public/v1/job/$JobId/" -Headers $h
Start-Sleep -Milliseconds 800
$skills = Invoke-RestMethod -Method Get -Uri "$Base/public/v1/job/$JobId/skill/" -Headers $h
# skills response shape: either array directly or {results: [...]}
$skillList = if ($skills.results) { $skills.results } else { $skills }
return @{ detail = $detail; skills = $skillList }
