# 8vance Talent Import — Claude Code Skill

End-to-end pipeline for generating and uploading realistic, fully-populated fictitious test talents to the **8vance Public API** (production or acceptance). Built for **Claude Code**.

Two modes:
- **A — Vacancy-based**: pulls existing job(s) + their skill taxonomy from your tenant, then generates talents that match (~80% skill overlap, realistic locations, German names for DE jobs, etc).
- **B — Free-form**: generate talents from a plain-language spec ("10 senior backend engineers in Berlin"), no vacancy basis.

Uses the **canonical `POST /public/v1/talent/`** endpoint (returns 201 with full data) rather than the broken `/import/talent/` endpoint that creates empty shells via a flaky HR-XML parser.

## What it produces per talent

- `first_name`, `last_name`, `email` (unique `@example.test`), `phone`, `date_of_birth`
- `linkedin`, `website`, `about_me`, `participate_in_matching: true`
- `availability_start_date`, hours range, source name
- **5 education entries** (Grundschule → Gymnasium → FH/Uni → Master → Cert for DE)
- **4 job-experience entries** (chronological, last current with `end_date: null`)
- **~10 skills** (proficiency=Competent, taxonomy IDs from the vacancy)
- **2 languages** (DE native L5/5/5 + EN advanced L4/4/4 default)

All talents are immediately indexed by the matching engine. Verified by `POST /match/job/?talent_id=` showing the target vacancy in top matches.

## Installation

### Option A — Copy into your `~/.claude/skills/` dir
```bash
git clone <this-repo-url> ~/.claude/skills/8vance-talent-import
```
Claude Code auto-discovers it on next session.

### Option B — Install as a plugin
If your team distributes Claude Code skills via a plugin registry, package this dir as a plugin (see [Claude Code plugin docs](https://docs.claude.com/claude-code)).

## Usage

In any Claude Code session, just say what you want:

> "Maak 5 talenten voor company 34330"
> "Genereer 10 senior accountants in Berlijn voor Kaufland"
> "Upload 3 testkandidaten per vacature voor company 34329"

Claude will:
1. **Ask** for `client_id` + `client_secret` if not provided (never hardcoded).
2. Ask for environment (prod/acc), mode, spec, locale.
3. Auth + source lookup via API.
4. Mode A: fetch vacancies. Mode B: resolve skill names.
5. Generate talents in-context.
6. **Show you a sample-of-1** for approval before mass upload.
7. Upload + enrich sequentially (1-2 sec rate-limited).
8. Verify 3-5 random talents.
9. Run a match test (target vacancy should appear in top-7 for Mode A).
10. Report with sample names + log paths.

Output files land in `talents_workspace/` in your current directory:
- `_sources.json` — cached source_name per company
- `{tenant}_{job_id}.json` or `{tenant}_freeform_{ts}.json` — generated talent arrays
- `_imported.jsonl` — `{tenant, job_id, talent_id, talent_name, selectedSkillsID}` per talent
- `_uploadlog.csv`, `_enrichlog.csv` — audit logs

## Requirements

- **Claude Code** (CLI or IDE)
- **PowerShell** (Windows) — scripts are PS-based. macOS/Linux: convert to bash/Python or invoke via `pwsh`.
- **8vance client credentials** with `talent_importer` scope at minimum
- Network access to `app.8vance.com` (or `acc.8vance.com`)

## Safety conventions

- **Test data only**: emails are always `@example.test`, no real PII
- **Never hardcoded credentials**: skill always asks; nothing is checked into git
- **Confirm before bulk upload**: 1 sample shown to user first
- **Rate limit aware**: 1-2 sec/call, respects 429 Retry-After
- **`participate_in_matching: true`** so matches work, but talents tagged with company-specific `source` (visible only to your company)

## Project structure

```
8vance-talent-import/
├── SKILL.md                       # entry point Claude reads
├── README.md                      # this file
├── LICENSE
├── .gitignore
├── references/
│   ├── endpoints.md               # full API endpoint reference
│   ├── talent_payload.md          # canonical request body shapes
│   ├── api_quirks.md              # 15 known issues + workarounds
│   ├── taxonomy_ids.md            # languages, proficiency, education_status
│   └── german_cities.md           # DE cities + PLZ per region
└── scripts/                       # PowerShell helpers (reference impls)
    ├── auth.ps1
    ├── lookup_source.ps1
    ├── fetch_job.ps1
    ├── create_talent.ps1
    ├── attach_subresources.ps1
    ├── verify_talent.ps1
    └── match_test.ps1
```

## Known limitations

- `POST /match/talent/?job_id=` (reverse direction) returns 0 with `client_credentials` grants. Use forward direction `POST /match/job/?talent_id=` for verification.
- `/talent/{id}/location/` sub-resource requires `latitude`+`longitude` decimal strings; skip it unless you geocode.
- `/import/talent/` endpoint is bypassed entirely (see `references/api_quirks.md` for why).
- PowerShell 5.1 + non-ASCII chars (em-dash, smart quotes) breaks the parser; scripts avoid them.
- Generated emails use `@example.test` — your tenant may need to whitelist this TLD to avoid bounce logic.

## Contributing

PRs welcome. Run a sample upload in **acceptance** (`https://acc.8vance.com`), not production, when testing changes. Update `references/api_quirks.md` whenever you encounter a new edge case.

## License

MIT — see [LICENSE](LICENSE).

## Built by

Internal 8vance / Claude Code experiment, May 2026. Distilled from a 108-talent test data run for Lidl + Kaufland on production.
