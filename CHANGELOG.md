# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-04-22

### Changed

- `/record-scenario` now writes to `drafts/` by default, consistent with `/crawl-site` and `/doc-to-scenarios`. Pass `--promote` to write directly to the scenario directory and auto-chain into `/review-scenario`. `--no-review` is only meaningful with `--promote`.

## [0.4.0] - 2026-04-21

### Added

- `/crawl-site` accepts natural-language descriptions after the URL (e.g., "focus on the checkout flow"). Claude interprets the intent, shows a crawl plan for approval, and prioritizes matching flows. Flags still work as explicit overrides.
- `/crawl-site` writes `.crawl-meta.json` with crawl history (URLs discovered/crawled/skipped, flow types, depth reached vs. available) for `/scenario-status`.
- `/scenario-status` coverage dashboard expanded with four dimensions: crawl depth (reached vs. available), flow type coverage (discovered → drafted → promoted → tested), scenario-to-test conversion rate, and critical path coverage (from `.critical-paths.md`).
- Language-aware config bootstrap: three-round prompting with project pre-scan. Test directory suggestions adapt to the chosen language.

### Changed

- `/spec-to-scenarios` renamed to `/doc-to-scenarios` — broadens input beyond QA specs to any document.
- `evaluate-spec` skill renamed to `evaluate-doc`.
- Terminology consolidated: "user story," "spec," and "user flow" → "doc."

## [0.3.0] - 2026-04-17

### Added

- `USAGE.md` — LLM-optimized reference card for host projects. Covers commands, workflow, all 13 tags, do's/don'ts, troubleshooting, and config. README points users at it.
- Documentation website (Zensical) at `website/playwright-scenarios/`. Covers terminology, workflow (with Mermaid diagram), capabilities, and spec-writing guidance.
- GitHub Actions workflow (`.github/workflows/docs.yml`) to build and deploy the documentation site to GitHub Pages on push.
- GitHub release badge in README.

### Changed

- README slimmed from ~340 lines to ~205 lines. Conceptual/guidance content (terminology, workflow details, capabilities, spec-writing guidance) moved to the documentation website. Operational content (installation, host setup, configuration, plugin catalog) stays in README.
- Terminology grouped into three categories: Inputs, Plugin artifacts, Output (both README and USAGE.md).
- All medical/clinical examples replaced with bookstore examples (fixtures, scenarios, selectors, branches, iframes, regex patterns) across all commands, skills, and docs.
- Consistency fixes across all 8 commands:
  - "Steps" → "Phases" in `/record-scenario` and `/playwright-scenarios-config`.
  - Collision handling standardized to numeric suffix increment (`-v2`, `-v3`, ...).
  - `MALFORMED_CONFIG` abort message standardized across all commands.
  - "Determine Scenarios" → "Select scenario files" in `/review-scenario` and `/scenario-to-tests`.
  - `/record-scenario` now adds a provenance blockquote to written scenarios.

## [0.2.0] - 2026-04-16

### Added

- Per-project configuration via `.claude/playwright-scenarios.local.md` — required fields `scenario_dir`, `test_dir`, `test_language`, `test_framework`; optional advanced fields `source_root` and `base_test_class` for projects whose layout doesn't match standard source-set patterns. Three-round `AskUserQuestion` bootstrap: language first, then language-aware directory suggestions, then framework scoped to language.
- New `loading-config` skill — invoked at the start of every command. Source-root inference and base-test-class discovery with auto-persist on first resolve.
- New `/crawl-site` command — read-only traversal that seeds `<scenario_dir>/drafts/` with user-flow-oriented scenarios. Starts from a URL, walks same-origin links one hop out by default, never fills forms or clicks destructive buttons. Groups discoveries into plausible user journeys (primary nav, hero CTAs, auth-gate entry points, footer aggregate). Supports `--depth` and `--max-scenarios` flags.
- New `/playwright-scenarios-config` command — view/update config fields with a dedicated malformed-config recovery path.
- Explicit command flags replace natural-language heuristics: `--no-review` on `/record-scenario`, `--include-drafts` on `/review-scenario` and `/scenario-to-tests`, `--dry-run` on `/scenario-to-tests`.
- `playwright-cli` preflight check in `/review-scenario`, `/scenario-to-tests`, and `/crawl-site` with actionable install guidance.
- Subagent parallelism capped at 5 concurrent across all commands.
- Documented scenario-name → Kotlin-class-name conversion rules including leading-digit handling.
- 13 extended scenario format tags, all preserved by `/review-scenario` during rewrites:
  - `**Iframe:** <selector>` — declares actions target content inside an iframe; `**Iframe:** none` returns to the top-level page.
  - `**Branch:** <field> = <value>` — overrides one fixture field for alternate-path testing.
  - `**Intercept:** <url-pattern> → <status> [body]` — mocks network requests for error/edge-case testing.
  - `**Cookie:** <name>=<value>` — pre-sets cookies for auth state, feature flags, A/B buckets.
  - `**Storage:** <key>=<value>` — pre-sets localStorage/sessionStorage for client-side state.
  - `**Device:** <preset>` — emulates Playwright device presets for responsive testing.
  - `**Timeout:** <ms>` — per-scenario or per-test timeout override.
  - `**Cleanup:** <action>` — teardown action for test isolation.
  - Plus existing: `**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`.
- New `/doc-to-scenarios` command — converts evaluated QA specs into scenario markdown with proper tag mapping.
- New `/generate-fixture` command — scaffolds standardized JSON fixture files from specs, scenarios, or interactively.
- New `/scenario-status` command — health dashboard (review dates, test status, coverage gaps).
- New `evaluate-doc` skill — reads a QA document and produces a structured testability report.
- New `fixture-format` skill — defines canonical JSON fixture format shared across all generators.
- New `debugging-scenarios` skill — guides troubleshooting when generated tests fail.
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

[0.5.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/mattbobambrose/playwright-scenarios/releases/tag/0.1.0
