# Project (vacancy) creation — canonical payload + flow

8vance Match-app "Projects" are jobs on the public API. Create with `POST /public/v1/job/`,
then attach sub-resources, then verify completeness, then publish. Rate limit on `/job/`
is 60/min → pace 1.05s between calls; sub-resource POSTs ~0.5s.

## Step 0 — Resolve taxonomy ids (ALWAYS first)

Same pattern as the talent flow:

- **Skills**: `GET /resources/skill/?q={name}&lang={lc}&page_size=5` → pick exact `phrase`
  match or first result. Keep both the resolved id (`skill`) and the `skill_name` string
  for the audit file. Multi-word miss → retry with head token only.
- **Function name**: `GET /resources/function-name/?q={query}`. Build the query from the
  project title: strip seniority adjectives (`senior|junior|medior|ervaren|trainee|stagiair`)
  and any trailing `" voor X"` clause; fall back to the head token. function_name weighs
  HEAVILY in matching — wrong/missing → score ≈ 0 even with perfect skills.
- **Function level**: `/resources/function-level/` — EN ids 29-36
  (29 under supervision … 31 independent … 32 independent w/ responsibility … 36 executive).
- **Language / education_degree / education_type / industry_type**: corresponding
  `/resources/...` endpoints. Common: Dutch 953491, English 953493, German 953498;
  HBO Bachelor degree_id 11, WO Master 14.

## Step 1 — POST /public/v1/job/

Required by schema: `company`, `function_level`. Send the FULLEST payload possible.
Canonical full body (validated against a real Swagger example payload, 2026-06-12):

```json
{
  "company": 34094,
  "title": "Senior Web Developer",
  "description": "Full description of the role...",
  "looking_for_description": "Who we are looking for...",
  "offer_description": "What we offer...",
  "web_link": "https://example.com/vacancy",
  "video_url": "https://example.com/video",
  "status": 1,
  "source": "tenant_source_slug",
  "expiration_date": "2026-12-31",
  "start_date": "2026-07-01",
  "end_date": "2027-07-01",
  "working_hours_minimum": 32,
  "working_hours_maximum": 40,
  "experience_years_minimum": 3,
  "experience_years_maximum": 8,
  "salary_low": "4500.00",
  "salary_high": "6500.00",
  "salary_type": 1,
  "contract_type": 0,
  "job_type": 0,
  "work_remotely": false,
  "function_name": 31387276,
  "function_level": 31,
  "number_of_seats": 2,
  "display_hiring_company_information": true,
  "hiring_company_label": "Client name (optional, detachering)",
  "hiring_company_website": "https://client.example.com",
  "detailed_location": {
    "latitude": "51.4461",
    "longitude": "5.4612",
    "language_code": "nl",
    "street": "Philitelaan",
    "street_number": "67",
    "postal_code": "5617 AM",
    "city": "Eindhoven",
    "country": "Netherlands",
    "region": "Noord-Brabant"
  }
}
```

→ **201** with full Job object incl. `id` + `all_completeness_data`.

Field notes:
- `function_name`: **integer taxonomy id on write, name-string on read**. PATCH with a
  string → 400 "A valid integer is required". The int id is never returned on GET.
- `detailed_location`: `language_code` + `latitude` + `longitude` (as STRINGS) are
  required — without lat/lng: "Latitude is required" error. Optional extras: `street`,
  `street_number`, `street_additional_information`, `full_address`, `state`. Platform
  auto-fills placeholders (street_number "1", postal_code "0000") when omitted — normal.
- `work_remotely` is the field name on this body (GET also returns `work_remotely`).
  Some older docs show `remote_work` — use `work_remotely`.
- Enums: `status` 0 New / 1 Active / 2 Expired / 3 Archived / 4 Deactivated / 5 Deleted.
  `salary_type` 0 hour / 1 month / 2 year. `contract_type` + `job_type` from
  `/resources/function-type/` family — 0 is a valid default.
- Read-only / response-only fields — NEVER send: `id`, `published`,
  `all_completeness_data`, `activated_at`, `deactivated_at`, `number_of_applicants`,
  `number_of_selected_talents`, `skill_name`.
- Soft-delete: `PATCH {"status": 5}` — prefer over DELETE (DELETE cascades all sub-resources).

## Step 2 — Sub-resources (all FLAT arrays, no {count,results} wrapper)

### Skills — REQUIRED for matching
```
POST /job/{id}/skill/
Body: {"skill": <taxonomy_id>, "must_have": true, "experience": 5}
```
- Field is `skill` — NOT `skill_id` (that's the talent side; sending `skill_id` here
  silently fails validation). Known API inconsistency.
- **Attach 5+ skills with `must_have: true`**: verified 2026-06-01 — without must_have
  skills `essential_completeness` stays ~28% and `POST /match/talent/?job_id=` returns
  400 "Additional data needed {skills: 3 ...}". With 5 must-have skills completeness
  jumps to 100% and matching works.
- GET returns flat array; `.skill` = taxonomy id, `.id` = junction id.

### Location (when not set via detailed_location, or to enrich)
```
POST /job/{id}/location/
Body: {"city":"Eindhoven","country":"Netherlands","region":"Noord-Brabant",
       "postal_code":"5617 AM","language_code":"nl",
       "latitude":"51.4461","longitude":"5.4612"}
```
Flat top-level keys (NOT wrapped in `{"location": {...}}`). lat/lng as strings —
writer silently drops the row when missing.

### Language
```
POST /job/{id}/language/
Body: {"language": 953491, "read_level": 5, "write_level": 5, "speak_level": 5}
```

### Education degree
```
POST /job/{id}/education_degree/
Body: {"degree_id": 11, "degree_country_id": 1875}
```

### Education subject
```
POST /job/{id}/education_subject/
Body: {"education_type": 946551}    // id from /resources/education-type/
```

### Experience function
```
POST /job/{id}/experience-function/
Body: {"function_name": 2019913, "function_level_id": 31}
```
Note hyphen in path; `function_level_id` WITH _id suffix here (inconsistent with root body).

### Experience industry
```
POST /job/{id}/experience_industry/
Body: {"industry_type": 946551}    // id from /resources/industry-type/
```

## Step 2b — 2D taxonomy (taxonomy_2d) — REQUIRED since 2DTAX release

Verified live on ACC 2026-06-12 (real test-tenant job): essential completeness
now includes `taxonomy_2d` as a gate item — function_name alone is NOT enough.
Without it the job sticks at 85.71% and `/match/talent/` 400s with
"Additional data needed: {taxonomy_2d: 1}".

1. Resolve roles + fields of work from the title:
```
GET /resources/role-field-of-work/?q={title}
→ {title, level, level_id, roles: [{role_id, role_label, best_matching_labels}],
   fields_of_work: [{field_of_work_id, field_of_work_label, ...}],
   classification_metadata, errors}
```
(This is an AI classifier endpoint — slower than other resources; q = plain job title
works best, e.g. "belastingadviseur" → roles Adviser 10006 / Consultant 10087,
field_of_work Taxation 50329.)

2. PATCH the ids onto the job (top-level field `role_field_of_work`):
```
PATCH /job/{id}/
Body: {"role_field_of_work": {
  "classifier_input": "<job title>",
  "role_ids": [10006, 10087],
  "field_of_work_ids": [50329],
  "top_field_of_work_id": 50329,
  "specialisation_by_fow_ids": {}
}}
```
→ 200; read-back expands `roles`/`fields_of_work` with translations. Completeness
jumps to 100.00.

## Step 3 — Verify completeness

```
GET /job/{id}/           → all_completeness_data.essential_completeness_percentage == 100
GET /job/{id}/extended/  → job + ALL sub-resources in one call (skills, languages,
                           education_degrees, education_subjects, experience_functions,
                           experience_industries as nested arrays; plus CMS fields like
                           requirements, company_culture, external_apply_url)
```
Essential completeness items (live ACC 2026-06-12): **skills + job_type + taxonomy_2d +
function_level + detailed_location**. (`function_name` is no longer a separate gate item —
superseded by taxonomy_2d — but still set it: matching weighs it.) < 100% → match 400s.

Note: `offer_description` lands in extended `company_culture`,
`looking_for_description` in extended `requirements`.

## Step 4 — Activate ("publish")

```
PATCH /job/{id}/
Body: {"status": 1}
```
- `status: 1` + 100% essential completeness = ACTIVE project — this is the same state
  live UI-created active jobs have.
- The `published` flag CANNOT be set via client_credentials: `PATCH {"published": true}`
  returns 200 but the value stays false, and `POST /job/{id}/publish/` → 401. Reference
  jobs that are active in the Match app also show `published: false` — it's the
  career-portal publication flag, owned by user-grant/UI. Do NOT treat
  `published: false` as a failure.
- `visibility` ("team" / "ecosystem") is PATCHable if needed.

## Step 5 — Match test

```
POST /match/talent/?job_id={id}&page_size=10&min_score=0
Body: {"sources":["<source_name>"]}
```
Without `min_score=0` default threshold (~85%) filters everything to 0. Reverse index
rebuilds async (10-30 min); forward (`/match/job/?talent_id=`) is live.

## Audit outputs

Save to `talents_workspace/` next to the talent files:
- `{tenant}_project_{job_id}.json` — full payload as sent + resolved skill map
  `[{skill_name, skill_id}]`
- append to `_uploadlog.csv` / `_enrichlog.csv` same as talents
