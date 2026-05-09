# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `/record-scenario` now accepts an optional Start URL argument: `/record-scenario http://localhost:8080`, `/record-scenario http://localhost:8080 checkout-flow`, etc. When supplied, the codegen browser opens there directly and the previous always-prompt-for-URL step is skipped. Order doesn't matter — a token starting with `http://` / `https://` is the URL; a kebab-case token is the name. Bare `/record-scenario` and the existing name-only form (`/record-scenario checkout-flow`) are unchanged.
- `DOC_GUIDE.md` expansions: a "How to use this guide" section that frames the doc for the LLM that's reading it (don't critique these rules, apply them when drafting a test document); four new authoring rules (waits as observable transitions, modal/dialog boundaries, navigation type, deterministic test data for idempotent reruns); five new "Cannot Handle Well" rows (CAPTCHA, OTP/email verification, real-time multi-user sync, native browser dialogs, hardware integration); a per-test `Preconditions:` block in the document template; corresponding checklist items. The website's `writing-docs.md` page gained a closing "Full authoring rules" section pointing at `DOC_GUIDE.md` as the canonical rule set and naming the new categories. Tutorial Step 4 gained a `> **Tip:**` callout with practical placement advice (system prompt > mid-conversation paste; paste guide and request in the same message; recovery line if the LLM critiques anyway).
- `/scenario-status` now accepts an optional natural-language description that biases the report: `/scenario-status focus on what's broken`, `/scenario-status one-paragraph executive summary`, `/scenario-status only the checkout-related scenarios`. Phases 1–5 still gather the full picture so the report stays truthful; Phase 6 uses the description to lead with a tailored prose summary, condense or skip tangential sections, optionally filter the per-partition tables, and reorder the recommended actions. Bare `/scenario-status` is unchanged.
- `summary` and `signature` frontmatter fields on each command, plus `scripts/gen-command-table.py` — a Python stdlib-only generator that derives the Markdown command table from the frontmatter. The README's command table is now auto-generated between `<!-- COMMANDS:BEGIN -->` / `<!-- COMMANDS:END -->` markers; run `python3 scripts/gen-command-table.py --inplace README.md` after editing any command's `summary` or `signature`. CI-friendly `--check` flag exits 1 if the file would change. Other doc surfaces (USAGE.md, llms.txt, website `commands.md`) still need hand-editing for now.

### Changed

- `/scaffold-base-test`: the recommended option for the "Does your dev server expose a `POST /reset` endpoint?" prompt is now `No`, not `Yes`. Most real dev servers don't expose `/reset` — it's a deliberate test affordance that purpose-built fixture or demo apps add. Picking `Yes` reflexively was producing `BasePageTest`s that POSTed to a non-existent endpoint and 404'd silently on every spec. The prompt copy was also reworded to make `Yes` opt-in.

### Removed

- `/crawl-site` no longer prompts an interactive Structural / Shallow / Deep menu when invoked with a bare URL (introduced in 0.6.1). The "Structural overview" option matched default behavior anyway, the prompt didn't reliably fire across all sessions, and the post-bootstrap stack of prompts was friction without payoff. A bare URL now goes straight to defaults (structural crawl, depth 1, max 10 scenarios, no filtering); pass a description or flag for non-default behavior.

### Fixed

- Tutorial Step 1 now uses the real demo image name (`mattbobambrose/playwright-scenario-playground`) and the required `-p 8080:8080` port mapping, replacing the `<imageName>` placeholder. Adds an `installPlaywrightBrowsers` step so users who jump to the tutorial without reading the template README don't hit a missing-browser error on `/record-scenario`.

## [0.7.0] - 2026-05-02

### Added

- New `/scaffold-base-test` command. Generates a Kotlin + Kotest `BasePageTest` class at the parent of `<test_dir>` so `/scenario-to-tests` has something to extend. Prompts for three customizations: whether the dev server has a `POST /reset` endpoint, whether the browser lifecycle runs per spec or per test, and which Playwright browser (Chromium / Firefox / Webkit) to launch. Persists the generated class's FQN to `base_test_class` in `.claude/playwright-scenarios.local.md`. Refuses to overwrite an existing `BasePageTest.kt` or an already-set `base_test_class`. Currently supports `kotlin` + `kotest-stringspec` only — additional language/framework variants will land alongside their `/scenario-to-tests` generation paths.
- New `scaffold-base-test` skill backing the command. Owns the inline Kotlin template, variant rules, and file-write logic.

### Changed

- `loading-config`: when base-test-class discovery finds zero candidates, it now offers to scaffold one (default Yes) by handing off to the `scaffold-base-test` skill, then persists the resulting FQN to the config. Previously, zero matches emitted a warning and `/scenario-to-tests` produced classes with no `extends` clause and a TODO comment. The warning path is preserved as the No branch.

## [0.6.1] - 2026-05-02

### Changed

- `/crawl-site`: when invoked with only a URL (no description, no flags), the command now prompts the user with a short menu — **Structural overview** / **Shallow overview** / **Deep crawl** — instead of silently falling back to defaults. The selected option becomes the description for downstream interpretation. Invocations that include any description or any flag (`--depth`, `--max-scenarios`) skip the prompt.

## [0.6.0] - 2026-05-02

### ⚠️ Breaking changes

This release reorganizes scenario and test directory layouts. Any existing host project that uses earlier versions of the plugin will need to migrate by moving scenarios out of `<scenario_dir>/drafts/` (and out of any flat `<scenario_dir>/` location) into the new partition subdirectories.

### Changed

- **Scenarios are now partitioned by source command.** Three subdirectories under `<scenario_dir>` hold the output of each creation command:
  - `<scenario_dir>/record/` — written by `/record-scenario`
  - `<scenario_dir>/crawl/` — written by `/crawl-site`
  - `<scenario_dir>/convert/` — written by `/doc-to-scenarios`
- **Generated tests mirror the partition** at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt` — partitioned by source command and by scenario. The `<scenario-name>/` directory is kebab-case verbatim and purely organizational; the `.kt` file declares its package as `<SCENARIOS_PACKAGE>.<command>`.
- **`loading-config` scaffolds the six partition subdirectories** under `<scenario_dir>` and `<test_dir>` on first run.
- **`/review-scenario` and `/scenario-to-tests` recurse into all three partitions by default.** Pass a bare partition name (`record`, `crawl`, or `convert`) to scope the operation to that partition.
- **`/scenario-status` dashboard groups rows by partition** and tracks per-partition conversion rates.

### Removed

- **The `drafts/` concept is gone.** Every creation command writes its scenario directly to its partition; the scenario in its partition is the canonical artifact. Users hand-edit or delete scenarios in place before running `/review-scenario`.
- **`--include-drafts` flag** removed from `/review-scenario` and `/scenario-to-tests`.
- **`--promote` flag** removed from `/record-scenario` and `/doc-to-scenarios`.
- **`--no-review` flag** removed from `/record-scenario` (no command auto-chains anymore).
- **No `/promote-scenario` command.** Promotion was the bridge between drafts and the canonical location; with no draft step, there's nothing to promote.

### Migration guide

If you have an existing project using v0.5.x:

1. Move scenarios out of `<scenario_dir>/drafts/` into the appropriate partition (`record/`, `crawl/`, or `convert/`) based on which command authored them. Hand-written scenarios go into the partition you'd most associate them with.
2. Move flat scenarios from `<scenario_dir>/*.md` into the appropriate partition.
3. Delete any tests under `<test_dir>/` that were generated by v0.5.x — they live in a flat layout that v0.6 won't recognize. Re-run `/scenario-to-tests` to regenerate at the new partitioned paths.
4. Optionally delete `<scenario_dir>/drafts/.crawl-meta.json` after copying it to `<scenario_dir>/crawl/.crawl-meta.json` (its new location).

## [0.5.1] - 2026-05-01

### Added

- Documentation site: new "Commands & Skills" reference page covering all 8 commands and 5 skills (signatures, arguments, flags, examples).
- Documentation site: new "Troubleshooting" page for setup-time and operational failures, using a Symptom → Cause → Fix shape. Pairs with the existing `debugging-scenarios` skill, which covers generated-test failures.

### Changed

- `tutorial.md` replaced with a placeholder sketch oriented around language-template repos (template links and demo image to be filled in).
- `CLAUDE.md`: doc-propagation rule extended to include the website docs; new "Website docs (Zensical)" section noting the `zensical.toml` nav requirement and a slug-fragility warning for headings.
- `README.md`, `llms.txt`, and `llms-full.txt` synced with the new pages and the updated `CLAUDE.md`.

### Renamed

- `plugins/playwright-scenarios/SPEC_GUIDE.md` → `DOC_GUIDE.md`.
- `website/playwright-scenarios/docs/writing-specs.md` → `writing-docs.md`.

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

- `/spec-to-scenarios` renamed to `/doc-to-scenarios` — broadens input beyond specific formats to any document.
- `evaluate-spec` skill renamed to `evaluate-doc`.
- Terminology consolidated: "user story," "spec," and "user flow" → "doc."

## [0.3.0] - 2026-04-17

### Added

- `USAGE.md` — LLM-optimized reference card for host projects. Covers commands, workflow, all 13 tags, do's/don'ts, troubleshooting, and config. README points users at it.
- Documentation website (Zensical) at `website/playwright-scenarios/`. Covers terminology, workflow (with Mermaid diagram), capabilities, and document-writing guidance.
- GitHub Actions workflow (`.github/workflows/docs.yml`) to build and deploy the documentation site to GitHub Pages on push.
- GitHub release badge in README.

### Changed

- README slimmed from ~340 lines to ~205 lines. Conceptual/guidance content (terminology, workflow details, capabilities, document-writing guidance) moved to the documentation website. Operational content (installation, host setup, configuration, plugin catalog) stays in README.
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
- New `/doc-to-scenarios` command — converts evaluated documents into scenario markdown with proper tag mapping.
- New `/generate-fixture` command — scaffolds standardized JSON fixture files from documents, scenarios, or interactively.
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

[0.7.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.6.1...0.7.0
[0.6.1]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.5.1...0.6.0
[0.5.1]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.5.0...0.5.1
[0.5.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/mattbobambrose/playwright-scenarios/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/mattbobambrose/playwright-scenarios/releases/tag/0.1.0
