# 8vance Public API endpoints (used by this skill)

Base URLs:
- Production: `https://app.8vance.com`
- Acceptance:  `https://acc.8vance.com`

All endpoints under `/public/v1/`. Auth: `Authorization: Bearer <JWT>`.

## Auth
| Method | Path | Body | Returns |
|---|---|---|---|
| POST | /public/v1/auth/token/client/ | `{client_id, client_secret}` | `{access, refresh}` JWT ~10min |
| POST | /public/v1/auth/token/refresh/ | `{refresh}` | new `access` |

## Source discovery (per tenant)
| Method | Path | Returns |
|---|---|---|
| GET | /public/v1/company/{company_id}/sources/ | `[{source:{name,...}, is_default, accepted_types,...}]` |
| GET | /api/user-sources/ | flat list of all sources visible to this client |

## Vacancy / Job (Mode A)
| Method | Path | Returns |
|---|---|---|
| GET | /public/v1/job/?company={id}&page_size=100 | paginated list |
| GET | /public/v1/job/{id}/ | full job detail |
| GET | /public/v1/job/{id}/skill/ | array of `{id, skill_name, skill, experience, must_have}` |
| GET | /public/v1/job/{id}/language/ | array |

The `skill` integer field is the taxonomy ID — use directly.

## Talent CREATE + sub-resources
| Method | Path | Body | Returns |
|---|---|---|---|
| POST | /public/v1/talent/ | TalentRequest (see talent_payload.md) | 201 Talent |
| GET | /public/v1/talent/{id}/ | - | full Talent |
| PATCH | /public/v1/talent/{id}/ | partial TalentRequest | 200 Talent |
| DELETE | /public/v1/talent/{id}/ | - | 204 |
| GET | /public/v1/talent/?company_id={id}&page_size=200 | paginated list |
| POST | /public/v1/talent/{id}/skill/ | `{skill_id, proficiency_id, experience, active}` | 201 |
| GET | /public/v1/talent/{id}/skill/ | paginated `{count, results: [{skill, skill_name, proficiency, experience, active}]}` |
| POST | /public/v1/talent/{id}/education/ | `{school, start_date, end_date, description, education_status, degree_id?, education_type_id?, location_id?}` | 201 |
| GET | /public/v1/talent/{id}/education/ | paginated |
| POST | /public/v1/talent/{id}/job-experience/ | `{company_name, function_title, start_date, end_date, description, current_job, function_name_id?, function_level?, industry_type_id?}` | 201 |
| GET | /public/v1/talent/{id}/job-experience/ | paginated |
| POST | /public/v1/talent/{id}/language/ | `{language, first_language, read_level, write_level, speak_level}` | 201 |
| GET | /public/v1/talent/{id}/language/ | paginated |
| POST | /public/v1/talent/{id}/location/ | `{city, country, language_code, latitude, longitude, ...}` | 201 (needs lat/lng!) |
| GET | /public/v1/talent/{id}/location/ | paginated |

## Resources (taxonomy lookups)
| Method | Path | Description |
|---|---|---|
| GET | /public/v1/resources/skill/?q={name}&lang=en | skill taxonomy search |
| GET | /public/v1/resources/language/?q={name}&lang=en | language taxonomy |
| GET | /public/v1/resources/function-name/?q={name}&lang=en | function taxonomy |
| GET | /public/v1/resources/function-level/?lang=en | small enum |
| GET | /public/v1/resources/industry-type/?q={name}&lang=en | industry taxonomy |
| GET | /public/v1/resources/career-phase/?lang=en | small enum |
| GET | /public/v1/resources/skill-proficiency/?lang=en | proficiency enum |

## Match + Search
| Method | Path | Body | Returns |
|---|---|---|---|
| POST | /public/v1/match/job/?talent_id={id}&page_size=15 | `{"sources":["<name>"]}` | jobs matching this talent (WORKS) |
| POST | /public/v1/match/talent/?job_id={id}&page_size=15 | `{"sources":["<name>"]}` | talents matching this job (RETURNS 0 with client_credentials) |
| POST | /public/v1/async/job/match/?talent_id={id} | `{"sources":["<name>"]}` | `{task_id}` |
| GET | /public/v1/async/task-status/?task_id={t} | - | `{status}` |
| GET | /public/v1/async/job/results/?task_id={t}&talent_id={id} | - | results array |
| POST | /public/v1/search/job/ | `{"sources":["<name>"], keywords, location, ...}` | jobs matching criteria |
| POST | /public/v1/search/talent/ | same shape | talents matching criteria |

## Schema discovery
| Method | Path | Returns |
|---|---|---|
| GET | /swagger/ | Swagger UI HTML |
| GET | /schema/ | full OpenAPI 3.0.3 JSON |

## NOT exposed via public API (use UI instead)
- Vacancy creation (use Creator app)
- Company / user management (admin endpoints)
- Pipeline / shortlist mgmt (UI-only)
