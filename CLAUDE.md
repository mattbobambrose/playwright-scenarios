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

## Doc propagation

When adding or changing a command, skill, or config field, update all of: README.md, CHANGELOG.md, llms.txt, llms-full.txt.

## External dependency

`/review-scenario`, `/scenario-to-tests`, and `/crawl-site` require the `playwright-cli` skill (not shipped by this marketplace). It lives at `~/.claude/skills/playwright-cli/` and wraps `@playwright/cli` (`npm install -g @playwright/cli@latest`).

## Scenario format extensions

`authoring-scenarios` supports extended tags beyond the base Action/Expected format: `**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`. See the skill for semantics. `/review-scenario` preserves these during rewrites.
