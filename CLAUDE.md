# playwright-scenarios

Claude Code plugin marketplace. No application source — just plugin definitions under `plugins/`.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (lists plugins, versions, metadata).
- `plugins/<name>/.claude-plugin/plugin.json` — per-plugin manifest.
- `plugins/<name>/commands/` — slash commands (markdown with YAML frontmatter).
- `plugins/<name>/skills/<skill-name>/SKILL.md` — skills (auto-loaded by trigger description).

## Version bumps

When bumping a plugin version, update **both** `plugin.json` and the matching entry in `marketplace.json`, the embedded `"version": "..."` strings inside `llms-full.txt`'s annotated source-file snippets for those two files, and the bottom-of-file reference-link block in `CHANGELOG.md` (add `[X.Y.Z]: https://github.com/mattbobambrose/playwright-scenarios/compare/<previous>...X.Y.Z`). Then seal the `## [Unreleased]` section as `## [X.Y.Z] - YYYY-MM-DD` and add a fresh empty `## [Unreleased]` above it.

When a change renames a file, command, skill, term, or config field, record it under `## [Unreleased]` — never edit historical `CHANGELOG.md` entries to use the new name. They deliberately record names as of their release.

## Testing plugin changes

No automated tests. Validate by installing the plugin locally and running the commands against a real host project.

## Command namespacing when installed

When the plugin is installed via `/plugin install playwright-scenarios@playwright-scenarios`, slash commands are invoked with the namespace prefix: `/playwright-scenarios:crawl-site`, not the bare `/crawl-site`. This is Claude Code's standard plugin-skill namespacing — see [Claude Code's plugin docs](https://code.claude.com/docs/en/plugins). Local development with `claude --plugin-dir ./` may allow the bare form (which is why the tutorial uses bare names — it's authored against the dev-loop path), but anyone who installs from the marketplace will see the namespaced form. If someone reports "installed commands don't work," the first thing to check is whether they're using the namespaced form.

## Plugin runtime config

The `playwright-scenarios` plugin reads per-project settings from `.claude/playwright-scenarios.local.md` (YAML frontmatter: `scenario_dir`, `test_dir`, `test_language`, `test_framework`). Every command starts by invoking the `loading-config` skill, which prompts the user and creates the file on first use. Use `/playwright-scenarios-config` to re-prompt.
Optional advanced fields: `source_root`, `base_test_class` — auto-inferred and persisted; not prompted at bootstrap.

## Config file write authority

Only `loading-config` and `/playwright-scenarios-config` write `.claude/playwright-scenarios.local.md`. Other skills return values; their callers persist. Single-writer prevents racy/partial updates and keeps the malformed-recovery path well-defined.

## Skill error contract

Skills return short structured error codes (e.g. `MALFORMED_CONFIG: <reason>`, `UNSUPPORTED_COMBO: <combo>`, `TARGET_EXISTS: <path>`) and let the calling command produce the user-facing message. Keeps messaging in one place per command and prevents drift between sibling docs.

## Doc propagation

When adding or changing a command, skill, or config field, update all of: README.md, CHANGELOG.md, llms.txt, llms-full.txt, `plugins/playwright-scenarios/USAGE.md`, plus the matching page under `website/playwright-scenarios/docs/` (e.g. `commands.md`, `terminology.md`). When adding a new command, also extend the explicit trigger list inside `loading-config`'s SKILL `description` field — the skill keeps working without it (fuzzy match), but the list is what other docs cite as the canonical command roster.

**Generated command tables.** The command table in `README.md` is auto-generated from each command's frontmatter (`summary`, `signature` fields) by `scripts/gen-command-table.py`. After editing any of those frontmatter fields, regenerate with `python3 scripts/gen-command-table.py --inplace README.md`. Don't hand-edit the content between `<!-- COMMANDS:BEGIN -->` / `<!-- COMMANDS:END -->` markers — it gets clobbered on the next run. The script also has a `--check` flag for CI ("exit 1 if the file would change") — combine with `--inplace`, e.g. `python3 scripts/gen-command-table.py --inplace README.md --check`. Other table-shaped surfaces (USAGE.md's intent-keyed table, llms.txt's bullet list, the website `commands.md` quick reference) still need hand-editing — they have different shapes; migrate them by adding the right frontmatter fields and a corresponding renderer to the script.

## Kotlin template coupling

The website tutorial (`website/playwright-scenarios/docs/tutorial.md`) walks through the separate `mattbobambrose/playwright-scenarios-kotlin-template` repo and cites its concrete details — directory paths (`src/test/kotlin/com/bookshelf/scenarios/`, `src/test/docs/`), `make` targets (`make clean tests`), and shipped example files. Changes on either side must be mirrored: a renamed `make` target, moved/renamed sample file, or layout change in the template breaks the tutorial.

## Example URLs in docs

Use `https://mysite.com` as the placeholder host in command examples and scenario `**URL:**` lines. Leave functional or illustrative URLs alone: the tutorial's `http://localhost:8080` (the bundled demo's real address), `troubleshooting.md`'s `localhost:3000` entry, `debugging-scenarios`'s cross-origin `auth.provider.com` example, and `@example.com` example email addresses.

## Website docs (Zensical)

Pages live under `website/playwright-scenarios/docs/`. Nav order is set in `website/playwright-scenarios/zensical.toml` — new pages must be added to the `nav = [...]` array or they won't appear in the sidebar. Avoid backticks, dots, slashes, and parens in `##`/`###` headings if anything cross-links to them — slugs become fragile (the `## Config` section in `troubleshooting.md` was simplified for this reason). When a command and a skill share a name (e.g. `### /create-base-test` and `### create-base-test`), they slugify to the same anchor; disambiguate with `attr_list` (`### create-base-test {: #create-base-test-skill }`). In Mermaid diagrams, never use `(...)` inside `[...]` node labels — it silently breaks rendering. Strip the parenthetical or move it to surrounding prose.

**Loose lists with multi-paragraph items.** In a numbered list where any item has continuation content (indented paragraphs, code blocks, callouts), use blank-line separation between **every** block transition inside the list — including between adjacent list items. Without blank lines between items that have indented continuation content, Zensical's renderer absorbs the next item's marker into the previous item's prose (so `4. Clone the new repo...` ends up as inline text inside item 3 instead of starting item 4). Tutorial Step 1 hit this exact bug; the rule is mechanical but easy to forget.

## External dependency

`/review-scenario`, `/scenario-to-tests`, and `/crawl-site` require the `playwright-cli` skill (not shipped by this marketplace). It lives at `~/.claude/skills/playwright-cli/` and wraps `@playwright/cli` (`npm install -g @playwright/cli@latest`).

## Source folders

Scenario creation commands write to one of three folders: `<scenario_dir>/{crawl,record,convert}/`. Generated tests mirror at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`. Use `<command>` (not `<folder>`) as the placeholder in path templates everywhere. The scenario in its folder is the canonical artifact; users hand-edit or delete in place before `/review-scenario`.

## Scenario format extensions

`authoring-scenarios` supports extended tags beyond the base Action/Expected format: `**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`, `**Iframe:**`, `**Branch:**`, `**Intercept:**`, `**Cookie:**`, `**Storage:**`, `**Device:**`, `**Timeout:**`, `**Cleanup:**`. See the skill for semantics. `/review-scenario` preserves these during rewrites.
