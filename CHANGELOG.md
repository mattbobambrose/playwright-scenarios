# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-15

Initial release.

### Added

- `playwright-scenarios` plugin — scenario-driven Playwright + Kotest test authoring for JVM projects.
- Commands: `/record-scenario`, `/crawl-site`, `/review-scenario`, `/scenario-to-tests`, `/playwright-scenarios-config`.
- Skills: `authoring-scenarios` (scenario markdown format reference) and `loading-config` (reads and bootstraps per-project settings from `.claude/playwright-scenarios.local.md`).
- Per-project configuration via `.claude/playwright-scenarios.local.md` — required fields `scenario_dir`, `test_dir`, `test_language`, `test_framework`; optional advanced fields `source_root` and `base_test_class` for projects whose layout doesn't match the standard source-set patterns. First run of any command prompts the user for the required four and persists them.
- Default scenario directory is `src/test/scenarios/`; `scenarios/` at repo root is offered as a legacy alternative.
- Explicit command flags replace natural-language heuristics: `--no-review` on `/record-scenario`, `--include-drafts` on `/review-scenario` and `/scenario-to-tests`, `--dry-run` on `/scenario-to-tests`, and `--depth` / `--max-scenarios` on `/crawl-site`.
- `/crawl-site` — read-only traversal that seeds the drafts directory with user-flow-oriented scenarios. Starts from a URL, walks same-origin links one hop out by default, never fills forms or clicks destructive buttons, and groups discoveries into plausible user journeys (primary nav, hero CTAs, auth-gate entry points, footer aggregate). Ranks and caps output; draft filenames disambiguate with `-v2`/`-v3` instead of overwriting.
- `/review-scenario` and `/scenario-to-tests` preflight the `playwright-cli` binary (global or via `npx`) and abort with install guidance if it's missing.
- `/review-scenario` and `/scenario-to-tests` cap parallel subagents at 5 concurrent, batching additional scenarios.
- Documented scenario-name → Kotlin-class-name conversion rules including leading-digit handling.
- `/playwright-scenarios-config` has a dedicated recovery path for malformed config files — shows the broken content, confirms, backs up the old file, and re-bootstraps.
- Host-project setup documentation covering the required Gradle `recordScenario` and `installPlaywrightBrowsers` tasks, Playwright / Kotest dependencies, scenario directory conventions, base test class pattern, and `playwright-cli` install.
- MIT license.

### Notes

- Test generation is currently wired for `kotlin` + `kotest-stringspec` only. Other values for `test_language` / `test_framework` are accepted and persisted but `/scenario-to-tests` will abort with a clear message until their generation rules are added.

[0.1.0]: https://github.com/mattbobambrose/playwright-scenarios/releases/tag/0.1.0
