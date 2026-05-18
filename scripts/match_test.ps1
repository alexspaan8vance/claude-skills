# Run match-test for a talent (returns jobs that match this talent)
# Usage: $matches = & .\match_test.ps1 -Jwt $jwt -TalentId 215166568 -SourceName 'lidl'
param(
  [Parameter(Mandatory=$true)][string]$Jwt,
  [Parameter(Mandatory=$true)][long]$TalentId,
  [Parameter(Mandatory=$true)][string]$SourceName,
  [string]$Base = 'https://app.8vance.com',
  [int]$PageSize = 15
)
$h = @{ Authorization = "Bearer $Jwt" }
$body = '{"sources":["' + $SourceName + '"]}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$url = "$Base/public/v1/match/job/?talent_id=$TalentId&page_size=$PageSize&soft_matching=true&vector_matching=true"
$resp = Invoke-RestMethod -Method Post -Uri $url -Headers $h -ContentType 'application/json' -Body $bytes
return $resp
