# Common taxonomy IDs

## Languages (POST /talent/{id}/language/ `language` field)
| Language | ID (EN tax) | DE tax | NL tax |
|---|---|---|---|
| German | **953498** | 113348 | 960824 |
| English | **953493** | 113344 | 962675 |
| Dutch | lookup via `/resources/language/?q=Dutch&lang=en` | - | - |
| French | lookup via `?q=French` | - | - |

To lookup any language: `GET /public/v1/resources/language/?q=<name>&lang=en` → `results[0].id`.

## Skill proficiency (POST /talent/{id}/skill/ `proficiency_id`)
| ID | Name |
|---|---|
| 23 | Novice |
| 24 | Advanced |
| **25** | **Competent** (default) |
| 26 | Proficient |
| 27 | Expert |
| 28 | Master |

NEVER use 0 — API rejects.

## Education status (POST /talent/{id}/education/ `education_status`)
| ID | Name |
|---|---|
| 0 | In progress |
| 1 | Interrupted |
| **2** | **Completed** (default) |
| 3 | Other |

## Skills (taxonomy_id for skill_id)
Resolve via `/public/v1/resources/skill/?q=<name>&lang=en` — returns up to 10 candidates with `id` (use this), `phrase`, `translations.de.name`, `translations.nl.name`. Pick best match by exact phrase or first result.

Or get from existing vacancy: `/public/v1/job/{id}/skill/` → each result's `skill` field is the taxonomy id.

## Function names / levels / industries
- Function name: `/public/v1/resources/function-name/?q=<name>&lang=en`
- Function level: `/public/v1/resources/function-level/?lang=en` (small list)
- Industry: `/public/v1/resources/industry-type/?q=<name>&lang=en`
- Career phase: `/public/v1/resources/career-phase/?lang=en`

## Job status enum (talent.job_status)
0=ACTIVELY_LOOKING, 1=OPEN_TO_OFFERS, 2=NOT_LOOKING, 3=PASSIVE, 4=NEW_JOB_STARTING, 5=UNAVAILABLE, 6=OTHER.
