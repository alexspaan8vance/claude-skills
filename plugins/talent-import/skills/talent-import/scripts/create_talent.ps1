# Create a talent via POST /public/v1/talent/
# Returns the created talent_id (or $null on fail)
# Usage: $tid = & .\create_talent.ps1 -Jwt $jwt -Talent $hash -SourceName 'lidl'
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)]$Talent,
  [Parameter(Mandatory=$true)][string]$SourceName,
  [string]$Base = 'https://app.8vance.com'
)
$h = @{ Authorization = "Bearer $Jwt" }
$body = [ordered]@{
  first_name = $Talent.first_name
  last_name = $Talent.last_name
  email = $Talent.email
  phone = $Talent.phone
  date_of_birth = $Talent.date_of_birth
  about_me = $Talent.about_me
  linkedin = $Talent.linkedin
  website = $Talent.website
  participate_in_matching = $true
  source = $SourceName
  availability_start_date = $Talent.availability_start_date
  availability_end_date = $Talent.availability_end_date
  work_remotely = $false
  available = $true
  min_hours_per_week = if ($Talent.min_hours) { $Talent.min_hours } else { 32 }
  max_hours_per_week = if ($Talent.max_hours) { $Talent.max_hours } else { 40 }
}
$json = $body | ConvertTo-Json -Compress -Depth 6
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
try {
  $resp = Invoke-RestMethod -Method Post -Uri "$Base/public/v1/talent/" -Headers $h -ContentType 'application/json' -Body $bytes
  return $resp.id
} catch {
  Write-Warning ('Create failed: ' + $_.Exception.Response.StatusCode.value__ + ' ' + $_.ErrorDetails.Message)
  return $null
}
