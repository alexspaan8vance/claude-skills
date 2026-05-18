# 8vance API quirks (production)

Verified 2026-05-15/18 on prod with Lidl + Kaufland client_credentials.

## 1. AVOID `POST /public/v1/import/talent/`
Returns talent_id even on `400 Preprocessing error` but creates an **empty shell** (no first_name, no email, no skills). The "preprocessing" tries to parse an HR-XML-ish schema and fails silently for our generated structure.

**Use `POST /public/v1/talent/` instead** — returns 201 with the full talent object as confirmation. Canonical fields (first_name, last_name, email, source as string, etc).

## 2. `proficiency_id: 0` is INVALID
The n8n workflow body uses `proficiency_id: 0` but the API rejects:
```
{"proficiency":["Invalid pk \"0\" - object does not exist."]}
```
Use **25 (Competent)** as default. Other valid values: 23, 24, 26, 27, 28.

## 3. Sources required + must be valid for tenant
Match + search endpoints require body:
```json
{"sources": ["<name>"]}
```
Valid `<name>` values per tenant come from `GET /public/v1/company/{id}/sources/` → `source.name` field. For Lidl: `lidl`. For Kaufland: `kaufland`. Sending `["public"]` fails with `"Found invalid sources or not enough privileges"` (the sources_url helper is at `/api/user-sources/`).

## 4. `/match/talent/?job_id=` returns 0 (forward direction)
With client_credentials grants this endpoint always returns 0 results, even with `enable_match_threshold_ignore=true` and `force_ignore_threshold=true`. The scope behind these creds does not include the cross-tenant talent listing.

**Workaround**: use `POST /match/job/?talent_id=` (reverse direction) which works fine. Iterate talents and check if target vacancies appear in their top matches.

## 5. UTF-8 byte body for special chars
PowerShell `Invoke-RestMethod -Body $string` corrupts ä/ö/ü/é etc. Always send as bytes:
```powershell
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
Invoke-RestMethod -Body $bytes ...
```
Server returns `400 JSON parse error - 'utf-8' codec can't decode byte 0xc3` when this is wrong.

## 6. No em-dash `—` in PowerShell strings
PS 5.1 reads .ps1 files as ANSI when there's no BOM → `—` corrupts the parser and produces `"string is missing the terminator"` errors. Use `-` or `--` instead. Same for `…`, smart quotes, non-ASCII.

## 7. Sub-resource GETs are paginated
```
GET /talent/{id}/skill/
→ {"count": 12, "next": null, "previous": null, "results": [{...}, {...}]}
```
ALWAYS iterate `.results`. Iterating the wrapper object yields properties (`count`, `next`, etc) not entries.

## 8. `/talent/{id}/location/` requires lat/lng
```json
{"city": "Neckarsulm", "country": "Germany"}
→ 400 {"non_field_errors":["Latitude is required"]}
```
Plus `language_code` required. Skip the location sub-resource unless geocoded.

## 9. JWT empty → cryptic error
If `auth/token/client/` fails or you don't extract `access`, the Authorization header becomes `Bearer ` (no value):
```
401 {"detail":"Authorization header must contain two space-delimited values","code":"bad_authorization_header"}
```
Always verify `$jwt.Length > 0` after auth.

## 10. JWT TTL ~10 min
Re-auth every ~7-8 min during long uploads. Lidl + Kaufland clients have separate token pools — re-auth per tenant when switching.

## 11. Rate limits (from prior memory + observation)
- `talent_importer` (create + sub-resources): 36000/hour → 10/sec OK; we use 1-2/sec to be safe
- `public` (GET on resources, sources, talent listing): 60/min → 1s between
- `auth` (token/client/ POST): 10/min → ≥6s between logins
- `apply_without_account`: 5/min

Throttle 429 returns `{"detail":"Request was throttled. Expected available in X second(s)"}`. Respect Retry-After or back off 2s, 4s, 8s.

## 12. /resources/skill/?q= is OPTIONAL for matching
When generating talents to match a vacancy, the `/job/{id}/skill/` response already includes `skill` (taxonomy_id) per entry. Use those directly in `selectedSkillsID` and `POST /talent/{id}/skill/`. No need to resolve names through `/resources/skill/?q=` (saves ~5 calls per job).

For Mode B (free-form, no vacancy), DO use `/resources/skill/?q=<name>&lang=en` to resolve user-given skill names to taxonomy IDs.

## 13. `/import/talent/` vs `/talent/` POST differ
Different schemas:
- `/import/talent/`: HR-XML nested (person.name.given, person.communication.address, profile.education[], etc) — uses parser that fails 99% of the time on AI-generated data
- `/talent/`: flat canonical (first_name, last_name, email, source as STRING) — 201 SUCCESS with proper data

## 14. PATCH /talent/{id}/ also works
For updating an existing talent. Use after `/import/talent/` shell if you absolutely must use that endpoint (we don't). Same body shape as POST /talent/.

## 15. `participate_in_matching` defaults to false
On `/import/talent/` it stays false; on `/talent/` POST you can set true directly. Always set true so the matching engine indexes the talent. After that, `/match/job/?talent_id=` will return matches.
