# 8vance Claude Skills

Marketplace of Claude Code skills + commands built by the **8vance engineering team**. Internal tooling for the 8vance Public API, n8n workflows, Zoho integrations, and recruiter automation, packaged so any colleague can install with one command.

## Quick install

In Claude Code:

```
/plugin marketplace add 8vance/claude-skills
/plugin install talent-import@8vance
```

Restart Claude Code and the skill is auto-discoverable on any `"maak X talenten"` style prompt.

## Available plugins

| Plugin | What it does |
|---|---|
| [`talent-import`](./plugins/talent-import) | Generate + upload realistic fictitious test talents to 8vance prod/acc. Two modes: vacancy-based matching, or free-form spec. Uses direct `POST /talent/` + sub-resource enrichment. |

More plugins coming as the team builds them — open a PR.

## What is a Claude Code plugin?

A plugin is a small package of skills, slash-commands, hooks, or MCP servers that Claude Code loads on demand. Skills are markdown-defined behaviors that auto-trigger on relevant prompts; they keep your CLAUDE.md clean while adding deep domain expertise.

This marketplace lets the 8vance team share that domain expertise across all team members' Claude installs.

## Repository structure

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json       # marketplace manifest (one file per plugin)
├── README.md                  # this file
├── LICENSE
├── .gitignore
└── plugins/
    └── talent-import/
        ├── .claude-plugin/plugin.json   # plugin manifest
        ├── README.md          # plugin docs
        └── skills/
            └── talent-import/
                ├── SKILL.md   # entry point Claude reads
                ├── references/ # docs Claude consults on demand
                └── scripts/    # PowerShell helpers
```

## Adding a new plugin

1. Create `plugins/<your-plugin>/.claude-plugin/plugin.json` with name + version + description.
2. Add skills under `plugins/<your-plugin>/skills/<skill-name>/SKILL.md`.
3. Add an entry to `.claude-plugin/marketplace.json` `plugins` array.
4. Open a PR. Once merged, colleagues `/plugin update <name>@8vance`.

## Safety conventions for all 8vance plugins

- **Never hardcode credentials** — always ask the user.
- **Confirm before destructive or bulk operations** — show 1 sample, ask "ship it?".
- **Rate-limit aware** — respect API rate-limit headers; back off on 429.
- **Test data only**: emails `@example.test`, no real PII.
- **Audit logs**: write CSV/JSONL of what was created so users can rollback.

## License

MIT — see [LICENSE](LICENSE).

## Maintainer

Contact #ai-team on Slack or `support@8vance.com`.
