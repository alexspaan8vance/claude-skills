# Attach all sub-resources to a talent (skills, education, job-experience, languages)
# Usage: & .\attach_subresources.ps1 -Jwt $jwt -TalentId 215166568 -Talent $hash
# $Talent hashtable must have: selectedSkillsID[], education[5], employment[4], languages[]
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)][long]$TalentId,
  [Parameter(Mandatory=$true)]$Talent,
  [string]$Base = 'https://app.8vance.com',
  [int]$SleepMs = 500
)
$h = @{ Authorization = "Bearer $Jwt" }
$counters = @{ skill=0; edu=0; job=0; lang=0; fail=0 }

function Post-Json($path, $obj) {
  $json = $obj | ConvertTo-Json -Compress -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  try {
    $null = Invoke-RestMethod -Method Post -Uri "$Base$path" -Headers $h -ContentType 'application/json' -Body $bytes -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

# Skills
foreach ($sid in @($Talent.selectedSkillsID)) {
  $ok = Post-Json "/public/v1/talent/$TalentId/skill/" ([ordered]@{
    skill_id = [int64]$sid; proficiency_id = 25; experience = 32764; active = $true
  })
  if ($ok) { $counters.skill++ } else { $counters.fail++ }
  Start-Sleep -Milliseconds $SleepMs
}

# Education
foreach ($e in @($Talent.education)) {
  $ok = Post-Json "/public/v1/talent/$TalentId/education/" ([ordered]@{
    school = $e.school
    start_date = $e.start_date
    end_date = $e.end_date
    description = $e.description
    education_status = 2
  })
  if ($ok) { $counters.edu++ } else { $counters.fail++ }
  Start-Sleep -Milliseconds $SleepMs
}

# Job experience
foreach ($j in @($Talent.employment)) {
  $endDate = $j.end_date
  $current = $false
  if ([string]::IsNullOrEmpty($endDate)) { $endDate = $null; $current = $true }
  $ok = Post-Json "/public/v1/talent/$TalentId/job-experience/" ([ordered]@{
    company_name = $j.company_name
    function_title = $j.function_title
    start_date = $j.start_date
    end_date = $endDate
    description = $j.description
    current_job = $current
  })
  if ($ok) { $counters.job++ } else { $counters.fail++ }
  Start-Sleep -Milliseconds $SleepMs
}

# Languages
# Default: DE native + EN advanced
$langs = $Talent.languages
if (-not $langs) {
  $langs = @(
    [ordered]@{ language = 953498; first_language = $true; read_level = 5; write_level = 5; speak_level = 5 },
    [ordered]@{ language = 953493; first_language = $false; read_level = 4; write_level = 4; speak_level = 4 }
  )
}
foreach ($l in $langs) {
  $ok = Post-Json "/public/v1/talent/$TalentId/language/" $l
  if ($ok) { $counters.lang++ } else { $counters.fail++ }
  Start-Sleep -Milliseconds $SleepMs
}

return $counters
