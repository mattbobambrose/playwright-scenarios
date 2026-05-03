# playwright-scenarios

Claude Code plugin marketplace. No application source — just plugin definitions under `plugins/`.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (lists plugins, versions, metadata).
- `plugins/<name>/.claude-plugin/plugin.json` — per-plugin manifest.
- `plugins/<name>/commands/` — slash commands (markdown with YAML frontmatter).
- `plugins/<name>/skills/<skill-name>/SKILL.md` — skills (auto-loaded by trigger description).

## Version bumps

When bumping a plugin version, update **both** `plugin.json` and the matching entry in `marketplace.json`, then add a `CHANGELOG.md` entry.

## Testing plugin changes

No automated tests. Validate by installing the plugin locally and running the commands against a real host project.

## Plugin runtime config

The `playwright-scenarios` plugin reads per-project settings from `.claude/playwright-scenarios.local.md` (YAML frontmatter: `scenario_dir`, `test_dir`, `test_language`, `test_framework`). Every command starts by invoking the `loading-config` skill, which prompts the user and creates the file on first use. Use `/playwright-scenarios-config` to re-prompt.
Optional advanced fields: `source_root`, `base_test_class` — auto-inferred and persisted; not prompted at bootstrap.

## Config file write authority

Only `loading-config` and `/playwright-scenarios-config` write `.claude/playwright-scenarios.local.md`. Other skills return values; their callers persist. Single-writer prevents racy/partial updates and keeps the malformed-recovery path well-defined.

## Skill error contract

Skills return short structured error codes (e.g. `MALFORMED_CONFIG: <reason>`, `UNSUPPORTED_COMBO: <combo>`, `TARGET_EXISTS: <path>`) and let the calling command produce the user-facing message. Keeps messaging in one place per command and prevents drift between sibling docs.

## Doc propagation

When adding or changing a command, skill, or config field, update all of: README.md, CHANGELOG.md, llms.txt, llms-full.txt, plus the matching page under `website/playwright-scenarios/docs/` (e.g. `commands.md`, `terminology.md`). When adding a new command, also extend the explicit trigger list inside `loading-config`'s SKILL `description` field — the skill keeps working without it (fuzzy match), but the list is what other docs cite as the canonical command roster.

## Website docs (Zensical)

Pages live under `website/playwright-scenarios/docs/`. Nav order is set in `website/playwright-scenarios/zensical.toml` — new pages must be added to the `nav = [...]` array or they won't appear in the sidebar. Avoid backticks, dots, slashes, and parens in `##`/`###` headings if anything cross-links to them — slugs become fragile (the `## Config` section in `troubleshooting.md` was simplified for this reason). When a command and a skill share a name (e.g. `### /scaffold-base-test` and `### scaffold-base-test`), they slugify to the same anchor; disambiguate with `attr_list` (`### scaffold-base-test {: #scaffold-base-test-skill }`). In Mermaid diagrams, never use `(...)` inside `[...]` node labels — it silently breaks rendering. Strip the parenthetical or move it to surrounding prose.

## External dependency

`/review-scenario`, `/scenario-to-tests`, and `/crawl-site` require the `playwright-cli` skill (not shipped by this marketplace). It lives at `~/.claude/skills/playwright-cli/` and wraps `@playwright/cli` (`npm install -g @playwright/cli@latest`).

## Source partitions

Scenario creation commands write to one of three partitions: `<scenario_dir>/{record,crawl,convert}/`. Generated tests mirror at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`. Use `<command>` (not `<partition>`) as the placeholder in path templates everywhere. There is no draft step — the scenario in its partition is the canonical artifact; users hand-edit or delete in place before `/review-scenario`.

## Scenario format extensions

`authoring-scenarios` supports extended tags beyond the base Action/Expected format: `**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`, `**Iframe:**`, `**Branch:**`, `**Intercept:**`, `**Cookie:**`, `**Storage:**`, `**Device:**`, `**Timeout:**`, `**Cleanup:**`. See the skill for semantics. `/review-scenario` preserves these during rewrites.
