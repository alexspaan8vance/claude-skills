# Verify a talent has full data populated
# Usage: & .\verify_talent.ps1 -Jwt $jwt -TalentId 215166568
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)][long]$TalentId,
  [string]$Base = 'https://app.8vance.com'
)
$h = @{ Authorization = "Bearer $Jwt" }
$t = Invoke-RestMethod -Method Get -Uri "$Base/public/v1/talent/$TalentId/" -Headers $h
Start-Sleep -Milliseconds 800
$skills = (Invoke-RestMethod -Method Get -Uri "$Base/public/v1/talent/$TalentId/skill/" -Headers $h).count
Start-Sleep -Milliseconds 800
$edu = (Invoke-RestMethod -Method Get -Uri "$Base/public/v1/talent/$TalentId/education/" -Headers $h).count
Start-Sleep -Milliseconds 800
$jobs = (Invoke-RestMethod -Method Get -Uri "$Base/public/v1/talent/$TalentId/job-experience/" -Headers $h).count
Start-Sleep -Milliseconds 800
$langs = (Invoke-RestMethod -Method Get -Uri "$Base/public/v1/talent/$TalentId/language/" -Headers $h).count

return [pscustomobject]@{
  id = $TalentId
  name = $t.first_name + ' ' + $t.last_name
  email = $t.email
  dob = $t.date_of_birth
  linkedin = $t.linkedin
  participate_in_matching = $t.participate_in_matching
  source = $t.source
  skills_count = $skills
  education_count = $edu
  jobexp_count = $jobs
  languages_count = $langs
}
