---
name: 8vance-talent-import
description: Generate and upload realistic, fully-populated fictitious talent profiles AND projects (vacancies/jobs) to 8vance production API. Three modes - (A) vacancy-based - fetch jobs, generate talents that match the vacancy's skills/location, upload them; (B) free-form - generate generic talents from a natural-language spec; (C) project creation - create complete, matching-ready vacancies via POST /job/ with full payload + sub-resources. Handles auth, source lookup, talent create via POST /talent/, sub-resource enrichment (skills, education, job-experience, language), and taxonomy resolution. Use when user wants to create test talents or projects/vacancies in 8vance. Trigger phrases - "maak X talenten", "upload talenten naar 8vance", "test data voor vacature", "generate candidates", "create talents", "maak een project", "maak vacatures", "create projects".
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

**Content-Type gotcha**: send `application/json` plain (NOT `application/json; charset=utf-8` — API rejects with 400 "Incorrect content type"). PowerShell: use `-ContentType 'application/json'` on Invoke-WebRequest/RestMethod.

**PS5.1 umlaut gotcha**: literal `ü/ö/ä` in .ps1 source gets read as Windows-1252, then `UTF8.GetBytes` produces wrong bytes → API stores mojibake. Use `[char]` codepoints:
```powershell
$U=[char]0x00FC; $A=[char]0x00E4; $O=[char]0x00F6
$Muenchen = "M$($U)nchen"
```

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
- **4 employment entries** (HARD MINIMUM 3): chronological, last current (`end: null`, `current_job: true`); past dates ≤ today
- **5 education entries** (HARD MINIMUM 2): Grundschule → Gymnasium → FH/Uni → Master → Cert (DE) or local equivalent
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

**Location sub-resource** (`POST /talent/{id}/location/`) is REQUIRED for matching. Required body (decimal strings for coords):
```json
{
  "latitude":"52.5200","longitude":"13.4050","language_code":"de",
  "city":"Berlin","country":"DE","postal_code":"10115","region":"Berlin",
  "street":"Hauptstrasse 10","full_address":"Hauptstrasse 10, 10115 Berlin, DE"
}
```
**CRITICAL: use POST, NOT PATCH** — PATCH returns 200 with populated body but is a silent no-op. POST persists correctly. Verify via raw bytes (GET endpoint may return empty placeholder even after successful POST — view bug):
```powershell
$resp = Invoke-WebRequest -Uri "$BASE/talent/$tid/location/" -Headers $h -UseBasicParsing
[Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()) | ConvertFrom-Json
```

### Step 6b — POST-create PATCH to link function_name + degree taxonomies

Sub-resource POSTs accept text-only data. Engine does NOT auto-link `function_title` → function_name taxonomy. Without taxonomy IDs the matching engine cannot weigh role match. After all sub-resources POSTed, PATCH each entry:

```
PATCH /talent/{id}/job-experience/{exp_id}/
Body: {function_name_id: <int>, industry_type: <int>, function_title: "Senior X", description: "..."}
```
- **field is `function_name_id`** (with _id suffix) — `function_name` (no suffix) silently accepts int but doesn't link
- **field is `industry_type`** (NO _id suffix) — inconsistent naming
- **DO NOT send `function_level`** — PATCH endpoint returns 500 server error; signal Junior/Mid/Senior via `function_title` text only
- Setting `function_name_id` on any job-experience auto-creates a `/talent/{id}/functional-area/` entry (talent's preferred role for matching)

```
PATCH /talent/{id}/education/{edu_id}/
Body: {degree_id: 1414, education_type_id: 953455, school: "Universität Hamburg", description: "B.Sc. Informatik"}
```
- **fields are `degree_id` + `education_type_id`** (with _id suffix) — `degree` and `education_type` without suffix → 400 or silent no-op
- Common IDs: 1414=University Bachelor, 1413=University Master, 953455=Higher studies in higher education, 953462=Secondary general/high school

### Step 6c — Set talent visibility for matching engine

```
PATCH /talent/{id}/
Body: {participate_in_matching: true, available: true, data_ownership: 1, job_status: 1, work_remotely: true, availability_start_date: "<today>"}
```
- `data_ownership: 1` = open/discoverable (default 0 = private)
- `availability_start_date` in past or today = "available now" (future date may be filtered out)
- `job_status: 1` = actively looking

### Step 6d — KNOWN BLOCKED endpoints (client_credentials grant)
- `POST /talent/{id}/function-name/` → 401 (top-level talent function — set via job-experience instead)
- `POST /job/{id}/publish/` → 401 (publish via UI or user-grant)
- `POST /shortlist/...` → 401
- `POST /match/refresh/`, `/match/rebuild/` → 401 / not exposed

~16-20 calls per talent including PATCHes = ~10 sec/talent.

### Step 7 — Verify (sample 3-5)
```
GET /talent/{id}/              → confirm name, email
GET /talent/{id}/skill/        → response is {count, results: [...]}: check count
GET /talent/{id}/education/    → check count
GET /talent/{id}/job-experience/
GET /talent/{id}/language/
```
Iterate `.results` array — NOT the wrapper object.

### Step 8 — Test matching

**Forward** (talent → jobs):
```
POST /public/v1/match/job/?talent_id={id}&page_size=15
Body: {"sources":["<source_name>"]}
→ jobs with score field, 70-90% expected on Mode A target
```

**Reverse** (job → talents):
```
POST /public/v1/match/talent/?job_id={id}&page_size=10&min_score=0
Body: {"sources":["<source_name>"]}
```
Without `&min_score=0` the endpoint defaults to a high threshold (~85%) and returns 0 even when talents are indexed. With `min_score=0` (or `debug=true`) all indexed talents surface.

**Indexing delay**: reverse-match index rebuilds asynchronously after talent create/PATCH. Allow 10-30 min before testing. Forward direction is live-computed and works immediately.

**UI display caveats**:
- Career portal (`career.8vance.com`) may filter by `source.is_public` — talents in a private (is_public:false) source won't see same-source vacancies via career portal.
- Recruiter app talent-match tab requires reverse-index entry. If index not yet built → "no matches" in UI even though API forward shows 80-90%.

## Mode C — Project (vacancy) creation

8vance "Projects" (Match app) = jobs on the public API. There is NO `/project/` endpoint — create via `POST /public/v1/job/`. Full payload reference + sub-resource bodies + completeness gates: `references/project_payload.md`. Read that file BEFORE creating any project.

Condensed flow (full detail in the reference):
1. **Resolve taxonomy ids first** — same pattern as talents: `GET /resources/skill/?q={name}&lang={lc}` for each skill (keep BOTH `skill_name` + resolved `skill` id), `GET /resources/function-name/?q={title}` for function_name (strip seniority adjectives + "voor X" clause from title before lookup; fall back to head token).
2. `POST /job/` with the FULLEST possible payload (see reference: salary, hours, experience years, dates, contract_type, work_remotely, detailed_location with lat/lng strings, function_name int, function_level, number_of_seats, descriptions).
3. Attach sub-resources: skills (`{"skill": <id>, "must_have": true, "experience": 5}` — **5+ must_have skills** or matching 400s), location (POST, lat/lng strings), language, education_degree, experience-function, experience_industry.
4. **2D taxonomy (REQUIRED, 2DTAX release)**: `GET /resources/role-field-of-work/?q={title}` → PATCH `/job/{id}/` with `{"role_field_of_work": {classifier_input, role_ids, field_of_work_ids, top_field_of_work_id, specialisation_by_fow_ids: {}}}`. Without this, completeness caps at ~86% and matching 400s on `taxonomy_2d`.
5. Verify completeness: `GET /job/{id}/` → `all_completeness_data.essential_completeness_percentage` must be 100 (gate items: skills + job_type + taxonomy_2d + function_level + detailed_location).
6. Activate: `PATCH /job/{id}/` `{"status": 1}`. The `published` flag is NOT settable via client_credentials (PATCH silently ignored, `POST /job/{id}/publish/` → 401) and active UI jobs also show `published: false` — status 1 + 100% completeness IS the active state.

Key gotchas (mirror talent quirks): `function_name` = **int on write, string on read**; job skill field is `skill` (NOT `skill_id` like talent); rate limit `/job/` = 60/min (pace 1.05s).

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
- `project_payload.md` — Mode C: canonical POST /job/ full body + job sub-resources + completeness gates + publish flow
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

## Known quirks (full list in references/api_quirks.md)
1. **AVOID `/import/talent/`** — creates empty shell on parse failure. Use `POST /talent/` instead.
2. **`proficiency_id: 0` INVALID** — use 25 (Competent). Other: 23-28.
3. **Sources required in match body** — `{"sources":["<name>"]}` from `/company/{id}/sources/`.
4. **Reverse match needs `min_score=0` query param** — default threshold filters all results to 0.
5. **UTF-8 body bytes** — always `[System.Text.Encoding]::UTF8.GetBytes($json)`.
6. **Content-Type `application/json` plain** — `charset=utf-8` suffix → 400.
7. **PS 5.1 umlaut bug** — use `[char]0x00FC/0xE4/0xF6` not literal `ü/ä/ö`.
8. **No em-dash** `—` in PS strings — use `-` or `--`.
9. **`$var:` in strings** → ParserError. Use `${var}:` or `$($var):`.
10. **Sub-resource GET paginated** (talent side) — iterate `.results`. EXCEPT `/job/{id}/skill/` which returns plain array.
11. **`POST /talent/{id}/location/`** — REQUIRED for matching. PATCH is no-op; always POST.
12. **`function_name_id` (with _id suffix)** on job-experience — `function_name` is silent no-op.
13. **`degree_id` + `education_type_id`** on education — non-_id versions don't work.
14. **`function_level` on job-experience → 500** — skip this field on PATCH.
15. **`industry_type` on job-experience** — NO `_id` suffix (inconsistent with function_name_id).
16. **`job.published` is read-only** — to publish: PATCH `status: 1` and require prereqs (3+ skills, function_name, function_level, location, job_type).
17. **`/talent/{id}/function-name/` → 401** for client_credentials. Set role via job-experience.function_name_id (auto-creates functional-area).
18. **`/talent/{id}/functional-area/` GET** shows talent's preferred role taxonomy — auto-created from job-experience function_name_id.
19. **Hashtable key int/string mismatch** — `$h[1234]` vs `$h["1234"]` returns null on type mismatch. Use string keys.
20. **JWT must be non-empty** — check `$jwt.Length > 0`.
21. **Reverse match indexing delay** — 10-30 min after PATCH. Forward match is live.
22. **Source `is_public: false`** + UI: career portal hides private-source jobs from talents.
