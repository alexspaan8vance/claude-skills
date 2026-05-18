# Canonical request body shapes

All POSTs require `Content-Type: application/json` and `Authorization: Bearer <jwt>`. Send body as UTF-8 bytes when it contains ä/ö/ü.

## POST /public/v1/talent/

```json
{
  "first_name": "Max",
  "last_name": "Müller",
  "email": "max.mueller.483921@example.test",
  "phone": "+497132111223",
  "date_of_birth": "1990-06-15",
  "about_me": "Erfahrener Spezialist mit Hintergrund in...",
  "website": "https://www.facebook.com/max.mueller",
  "linkedin": "https://www.linkedin.com/in/max-mueller",
  "youtube": null,
  "participate_in_matching": true,
  "source": "lidl",
  "availability_start_date": "2026-07-01",
  "availability_end_date": null,
  "work_remotely": false,
  "available": true,
  "min_hours_per_week": 32,
  "max_hours_per_week": 40
}
```
Response: 201 with full Talent object including `id` (use as `talent_id` for sub-resources).

Required fields: `first_name`, `last_name`, `email`, `source`. All else optional.

## POST /talent/{id}/skill/

```json
{"skill_id": 972571, "proficiency_id": 25, "experience": 32764, "active": true}
```
- `skill_id`: taxonomy integer from `/job/{id}/skill/` `skill` field or `/resources/skill/?q=...` result `id`.
- `proficiency_id`: 23=Novice, 24=Advanced, **25=Competent (default)**, 26=Proficient, 27=Expert, 28=Master. NEVER 0.
- `experience`: 32764 (workflow magic value).
- `active`: true.

## POST /talent/{id}/education/

```json
{
  "school": "Gymnasium Heilbronn",
  "start_date": "1998-08-21",
  "end_date": "2006-07-17",
  "description": "Allgemeine Hochschulreife mit Schwerpunkt Wirtschaft",
  "education_status": 2
}
```
- `education_status`: 0=in_progress, 1=interrupted, **2=completed (default)**, 3=other.
- All other fields optional.
- Optional: `degree_id`, `education_type_id`, `location_id` (require lookups).

## POST /talent/{id}/job-experience/

```json
{
  "company_name": "Allianz Technology",
  "function_title": "Junior Data Analyst",
  "start_date": "2012-07-22",
  "end_date": "2015-02-06",
  "description": "Implementierung von RPA-Bots in UiPath",
  "current_job": false
}
```
- Set `end_date: null` + `current_job: true` for current role.
- Optional: `function_name_id`, `function_level`, `industry_type_id`, `geographical_span_id`, `staff_responsibility_id`, `working_hours_per_week`, `contract_type`, `location`.

## POST /talent/{id}/language/

```json
{"language": 953498, "first_language": true, "read_level": 5, "write_level": 5, "speak_level": 5}
```
- `language`: taxonomy id. DE=**953498**, EN=**953493**, NL=lookup via `/resources/language/?q=Dutch`.
- `first_language`: true for native, false for second.
- Levels: 0-5 (0=none, 5=native).

## POST /talent/{id}/location/

```json
{
  "city": "Neckarsulm",
  "country": "Germany",
  "region": "Baden-Württemberg",
  "postal_code": "74172",
  "language_code": "de",
  "latitude": "49.1832",
  "longitude": "9.2366"
}
```
- `latitude`+`longitude` REQUIRED (decimal strings, not floats).
- `language_code` REQUIRED.
- Skip this sub-resource entirely unless you have geocoded coords — the talent's address is recorded elsewhere.

## PATCH /public/v1/talent/{id}/

Same body shape as POST /talent/ create body. Use for updates after creation.
