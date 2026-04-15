# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-15

Initial release.

### Added

- `playwright-scenarios` plugin — scenario-driven Playwright + Kotest test authoring for JVM projects.
- Commands: `/record-scenario`, `/review-scenario`, `/scenario-to-tests`, `/playwright-scenarios-config`.
- Skills: `authoring-scenarios` (scenario markdown format reference) and `loading-config` (reads and bootstraps per-project settings from `.claude/playwright-scenarios.local.md`).
- Per-project configuration via `.claude/playwright-scenarios.local.md` — `scenario_dir`, `test_dir`, `test_language`, `test_framework`. First run of any command prompts the user for these and persists them.
- Default scenario directory is `src/test/scenarios/`; `scenarios/` at repo root is offered as a legacy alternative.
- Host-project setup documentation covering the required Gradle `recordScenario` and `installPlaywrightBrowsers` tasks, Playwright / Kotest dependencies, scenario directory conventions, and base test class pattern.
- MIT license.

### Notes

- Test generation is currently wired for `kotlin` + `kotest-stringspec` only. Other values for `test_language` / `test_framework` are accepted and persisted but `/scenario-to-tests` will abort with a clear message until their generation rules are added.

[0.1.0]: https://github.com/mattbobambrose/playwright-scenarios/releases/tag/0.1.0
