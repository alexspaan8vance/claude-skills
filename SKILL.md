---
name: 8vance-talent-import
description: Generate and upload realistic, fully-populated fictitious talent profiles to 8vance production API. Two modes - (A) vacancy-based - fetch jobs, generate talents that match the vacancy's skills/location, upload them; (B) free-form - generate generic talents from a natural-language spec. Handles auth, source lookup, talent create via POST /talent/, plus sub-resource enrichment (skills, education, job-experience, language). Use when user wants to create test talents in 8vance. Trigger phrases - "maak X talenten", "upload talenten naar 8vance", "test data voor vacature", "generate candidates", "create talents".
---

# 8vance Talent Import

End-to-end pipeline to generate AND upload fictitious test talents to 8vance prod, fully populated and ready for matching.

## Inputs needed from user

**ALWAYS ask first — never assume.** Skill must be safe for any 8vance user; no hardcoded creds, company IDs, or tenant names.

Required (ask one at a time if missing):
1. **Credentials**: `client_id` + `client_secret` for the tenant (paste from 8vance admin panel).
2. **Environment**: prod (`https://app.8vance.com`) of acceptance (`https://acc.8vance.com`)? Default: prod.
3. **Mode**:
   - **A — vacancy-based**: fetch existing job(s), generate talents that match.
   - **B — free-form**: generate generic talents from a natural-language spec.
4. **Spec** (depends on mode):
   - Mode A: which `job_id`(s)? Or "all active jobs for company X"? How many talents per job? (default 3)
   - Mode B: count + description ("10 senior backend developers in Berlin"). Skill names if user wants specific skills.
5. **Match strictness** (Mode A, default 80%): % of vacancy skills the talent has.
6. **Locale** (default: auto-detect from vacancy country): DE/NL/EN/FR.
7. **CONFIRM before uploading**: show the user a sample-of-1 talent JSON locally before mass upload. They approve, then proceed.

If user gives only creds: discover what's available via:
- `GET /public/v1/company/` → which company they belong to
- `GET /public/v1/company/{id}/sources/` → default source_name
- `GET /public/v1/job/?company={id}&page_size=100` → list active jobs → ask which to use

## Pipeline overview

### Step 1 — Auth
```
POST https://app.8vance.com/public/v1/auth/token/client/
Content-Type: application/json
Body: {"client_id":"...","client_secret":"..."}
→ {access: JWT, refresh: ...}, JWT TTL ~10 min
```
Use `Authorization: Bearer <access>`. Refresh every 7 min.

### Step 2 — Discover source_name
```
GET /public/v1/company/{company_id}/sources/
→ [{source:{name:"lidl",...}, is_default:true, ...}]
```
Pick `source.name` where `is_default=true`. This is the `source` string for POST /talent/.

### Step 3 — Mode A: Fetch vacancies
For each `job_id`:
```
GET /public/v1/job/{id}/         → title, description, detailed_location, function_*
GET /public/v1/job/{id}/skill/   → list of {id, skill_name, skill (taxonomy_id), experience, must_have}
```
The `skill` integer is the **canonical taxonomy ID** — use directly. NO `/resources/skill/` lookup needed.

### Step 3 — Mode B: Skip vacancy fetch
Just plan N talents from user spec. Resolve skill names → taxonomy IDs via `/resources/skill/?q={name}&lang=en` (returns up to 10 candidates per query; pick the best match by `phrase` exact-match or first result).

### Step 4 — Generate talents in-context
Per talent, prepare data:
- **Names**: realistic per locale (DE: Müller/Schmidt/Schneider + Jonas/Lukas/Anna; NL: De Vries/Jansen + Jan/Sanne)
- **Email**: `firstname.lastname.{6-digit-random}@example.test` — UNIQUE per talent
- **Phone**: country-correct format
- **DOB**: 1985-2000 (YYYY-MM-DD)
- **Location**: within ~10 km of vacancy city (Mode A) or per spec (Mode B). See `references/german_cities.md`.
- **Skills**: Mode A → ⌈match_pct × N⌉ of vacancy's taxonomy IDs; Mode B → resolved IDs from spec
- **4 employment entries**: chronological, last current (`end: null`, `current_job: true`); past dates ≤ today
- **5 education entries**: Grundschule → Gymnasium → FH/Uni → Master → Cert (DE) or local equivalent
- **2 languages**: DE native L5/5/5 + EN L4/4/4 (or per locale)
- `participate_in_matching: true`
- `availability_start_date`: 1-3 months in future

Save each talent set as a JSON file in `talents_workspace/` for audit:
- Mode A: `{tenant}_{job_id}.json` (array of N)
- Mode B: `{tenant}_freeform_{timestamp}.json` (array of N)

### Step 5 — Create talent (DIRECT, no /import/ workaround)
```
POST /public/v1/talent/
Body: {
  first_name, last_name, email, phone, date_of_birth,
  about_me, linkedin, website,
  participate_in_matching: true,
  source: "<source_name>",
  availability_start_date, availability_end_date (or omit if null),
  work_remotely: false, available: true,
  min_hours_per_week: 32, max_hours_per_week: 40
}
→ 201 {id, ...full talent object}
```
Capture `id` → save mapping to `_imported.jsonl`. Rate: 1 sec per create.

**IMPORTANT:** Use UTF-8 byte body: `[System.Text.Encoding]::UTF8.GetBytes($json)`. String-body corrupts ä/ö/ü.

### Step 6 — Attach sub-resources per talent
For each created talent_id, run these POSTs (rate: 0.5 sec each):

```
POST /talent/{id}/skill/         Body: {skill_id, proficiency_id: 25, experience: 32764, active: true}
POST /talent/{id}/education/     Body: {school, start_date, end_date, description, education_status: 2}
POST /talent/{id}/job-experience/ Body: {company_name, function_title, start_date, end_date, description, current_job}
POST /talent/{id}/language/      Body: {language: 953498 (DE) or 953493 (EN), first_language, read_level 0-5, write_level, speak_level}
```
- `proficiency_id: 25` = Competent (NOT 0 — invalid pk). Other values: 23=Novice, 24=Advanced, 26=Proficient, 27=Expert, 28=Master.
- `experience: 32764` = magic value (works in production workflow).
- `current_job: true` when end_date is null/missing.
- For DE-native: DE first_language=true L5/5/5, EN first_language=false L4/4/4.

**Location sub-resource** (`POST /talent/{id}/location/`) requires `latitude`+`longitude` as decimal strings. **Skip unless geocoded** — talents work fine without explicit location subresource since address is in the talent itself (via PATCH route) or just inherited.

~14 calls per talent = ~7 sec/talent.

### Step 7 — Verify (sample 3-5)
```
GET /talent/{id}/              → confirm name, email
GET /talent/{id}/skill/        → response is {count, results: [...]}: check count
GET /talent/{id}/education/    → check count
GET /talent/{id}/job-experience/
GET /talent/{id}/language/
```
Iterate `.results` array — NOT the wrapper object.

### Step 8 — Test matching (optional)
```
POST /public/v1/match/job/?talent_id={id}&page_size=15
Body: {"sources":["<source_name>"]}
→ returns jobs that match this talent
```
For Mode A: verify target vacancy appears in top matches (1-7 usually).

**NOTE:** `/match/talent/?job_id=X` (reverse direction) returns 0 with client_credentials grants. Use `/match/job/?talent_id` (forward) for verification.

## File outputs in `talents_workspace/`
- `_sources.json` — cached source_name per company
- `{tenant}_{job_id}.json` or `{tenant}_freeform_{ts}.json` — generated talent arrays
- `_imported.jsonl` — JSONL: `{tenant, job_id_or_freeform, talent_id, talent_name, selectedSkillsID}`
- `_uploadlog.csv` — POST /talent/ audit
- `_enrichlog.csv` — sub-resource POST audit

## Conventions
- Test data: emails `@example.test`, no real PII.
- Always tag with the tenant's default source.
- Always `participate_in_matching: true` (matching engine indexes them).
- Locations: within country of vacancy (Mode A) or spec (Mode B).
- Skills: Mode A → taxonomy IDs from vacancy itself; Mode B → resolved via `/resources/skill/?q=...`.

## Workflow summary for Claude

1. **Ask** for credentials, mode, count, spec, locale (one question at a time using AskUserQuestion when possible).
2. Auth + source lookup. Cache `source_name` per tenant.
3. **Mode A**: fetch each vacancy detail+skills via `/job/{id}/` + `/job/{id}/skill/`. **Mode B**: resolve skill names via `/resources/skill/?q=...` if user gave names; otherwise skip.
4. Generate talents in-context (Claude does this directly — NOT via sub-agent; keep visibility).
5. **Show 1 sample talent JSON to user → ask "ship 'em all?"**. Only proceed on confirmation.
6. Save talent JSONs locally to `talents_workspace/` (audit).
7. Sequential per talent:
   a. `POST /talent/` → capture id
   b. POST 5 education entries
   c. POST 4 job-experience entries
   d. POST N skill entries (~10 per talent)
   e. POST 2 language entries (DE+EN or per locale)
8. Verify 3-5 random via GET sub-resources.
9. Match-test 2-3 via `POST /match/job/?talent_id=` body `{"sources":["<name>"]}`. Report rank of target vacancy (Mode A).
10. Report: count, sample names, match positions, log paths.

## Reference docs in `references/`
- `talent_payload.md` — canonical POST /talent/ body + each sub-resource body shape
- `german_cities.md` — common DE cities + postal codes (Neckarsulm, Heilbronn, Bad Wimpfen, etc)
- `api_quirks.md` — known issues + workarounds
- `taxonomy_ids.md` — DE language id 953498, EN 953493, proficiency 23-28, education_status 0-3
- `endpoints.md` — full endpoint reference

## Helper scripts in `scripts/`
- `auth.ps1` — token fetch helper
- `lookup_source.ps1` — discover source_name
- `fetch_job.ps1` — get job + skills
- `create_talent.ps1` — POST /talent/ wrapper
- `attach_subresources.ps1` — full sub-resource batch per talent
- `verify_talent.ps1` — GET-back sample
- `match_test.ps1` — run match test

Copy + adapt per session. PowerShell target (Windows).

## Known quirks (in references/api_quirks.md)
1. **AVOID `/import/talent/`** — returns talent_id even on 400 "Preprocessing error" but creates empty shell. Use `POST /talent/` instead (201 with full data).
2. **`proficiency_id: 0` INVALID** — workflow uses 0 but API rejects. Use 25 (Competent).
3. **Sources required in match body** — `{"sources":["<name>"]}` from `/company/{id}/sources/`.
4. **Match talent direction blocked** — `/match/talent/?job_id` returns 0 with client_credentials. Use `/match/job/?talent_id`.
5. **UTF-8 body bytes** — for ä/ö/ü always `[System.Text.Encoding]::UTF8.GetBytes($json)`.
6. **No em-dash** `—` in PowerShell strings (PS 5.1 ANSI parser breaks). Use `-` or `--`.
7. **`Invoke-WebRequest -UseBasicParsing`** for raw responses; use `-f` operator over interpolation when in doubt.
8. **Sub-resource GETs paginated** — `{count, next, previous, results: [...]}`. Iterate `.results`.
9. **Location sub-resource requires lat/lng decimal strings** — skip unless geocoded.
10. **JWT must be non-empty** — check `$jwt.Length > 0` to avoid "Authorization header must contain two space-delimited values".
