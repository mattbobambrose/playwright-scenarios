# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-16

### Added

- Per-project configuration via `.claude/playwright-scenarios.local.md` — required fields `scenario_dir`, `test_dir`, `test_language`, `test_framework`; optional advanced fields `source_root` and `base_test_class` for projects whose layout doesn't match standard source-set patterns. Two-round `AskUserQuestion` bootstrap prevents invalid language/framework pairings.
- New `loading-config` skill — invoked at the start of every command. Source-root inference and base-test-class discovery with auto-persist on first resolve.
- New `/crawl-site` command — read-only traversal that seeds `<scenario_dir>/drafts/` with user-flow-oriented scenarios. Starts from a URL, walks same-origin links one hop out by default, never fills forms or clicks destructive buttons. Groups discoveries into plausible user journeys (primary nav, hero CTAs, auth-gate entry points, footer aggregate). Supports `--depth` and `--max-scenarios` flags.
- New `/playwright-scenarios-config` command — view/update config fields with a dedicated malformed-config recovery path.
- Explicit command flags replace natural-language heuristics: `--no-review` on `/record-scenario`, `--include-drafts` on `/review-scenario` and `/scenario-to-tests`, `--dry-run` on `/scenario-to-tests`.
- `playwright-cli` preflight check in `/review-scenario`, `/scenario-to-tests`, and `/crawl-site` with actionable install guidance.
- Subagent parallelism capped at 5 concurrent across all commands.
- Documented scenario-name → Kotlin-class-name conversion rules including leading-digit handling.
- Extended scenario format tags: `**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`. Preserved by `/review-scenario` during rewrites.
- Default scenario directory changed from `scenarios/` to `src/test/scenarios/`; legacy location offered as an alternative.

### Notes

- Test generation is currently wired for `kotlin` + `kotest-stringspec` only. Other values for `test_language` / `test_framework` are accepted and persisted but `/scenario-to-tests` will abort with a clear message until their generation rules are added.

## [0.1.0] - 2026-04-15

Initial release.

### Added

- `playwright-scenarios` plugin — scenario-driven Playwright + Kotest test authoring for JVM projects.
- Commands: `/record-scenario`, `/review-scenario`, `/scenario-to-tests`.
- Skill: `authoring-scenarios` — auto-loads when Claude edits scenario markdown files.
- Host-project setup documentation covering the required Gradle `recordScenario` and `installPlaywrightBrowsers` tasks, Playwright / Kotest dependencies, `scenarios/` directory convention, and base test class pattern.
- MIT license.

[0.2.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/mattbobambrose/playwright-scenarios/releases/tag/0.1.0
