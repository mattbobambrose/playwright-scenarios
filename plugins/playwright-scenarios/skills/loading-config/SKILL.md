---
name: loading-config
description: Load per-project configuration for the playwright-scenarios plugin from .claude/playwright-scenarios.local.md. Triggers automatically at the start of any playwright-scenarios command (/record-scenario, /crawl-site, /doc-to-scenarios, /review-scenario, /scenario-to-tests, /scenario-status, /generate-fixture, /scaffold-base-test, /playwright-scenarios-config). Prompts the user for the four required fields (scenario_dir, test_dir, test_language, test_framework) on first run, persists them, and scaffolds the record/crawl/convert subdirectories under both <scenario_dir> and <test_dir>. Additional optional fields (source_root, base_test_class) are auto-inferred when needed and persisted on disambiguation. When base-test-class discovery finds zero candidates, offers to scaffold one via the scaffold-base-test skill.
---

# Loading Plugin Configuration

The `playwright-scenarios` plugin stores per-project settings in `.claude/playwright-scenarios.local.md` at the repo root. This skill resolves that config and returns the values the rest of the plugin consumes.

## Config file format

YAML frontmatter followed by a markdown body. Only the frontmatter is load-bearing; the body is free-form notes for humans.

```markdown
---
scenario_dir: src/test/scenarios
test_dir: src/test/kotlin/com/example/qa/scenarios
test_language: kotlin
test_framework: kotest-stringspec
# Optional, advanced:
# source_root: src/test/kotlin
# base_test_class: com.example.qa.BasePageTest
---

# Playwright Scenarios — Project Config

Edit the YAML frontmatter to reconfigure, or run `/playwright-scenarios-config` to re-prompt.
```

### Field semantics

| Field | Required | Default offered | Purpose |
|-------|----------|-----------------|---------|
| `scenario_dir` | **yes** | `src/test/scenarios` | Root directory (relative to repo root) for scenario `.md` files. Scenarios live under three command-keyed subdirectories: `<scenario_dir>/record/` (from `/record-scenario`), `<scenario_dir>/crawl/` (from `/crawl-site`), and `<scenario_dir>/convert/` (from `/doc-to-scenarios`). The bootstrap creates these subdirectories. |
| `test_dir` | **yes** | none (must be entered) | Root directory (relative to repo root) for generated test files. Tests are written under `<test_dir>/<command>/<scenario-name>/<ClassName>.<ext>` — partitioned by source command and by scenario. The bootstrap creates the three top-level subdirectories. |
| `test_language` | **yes** | `kotlin` | One of: `kotlin`, `java`, `typescript`, `python`, or any free-form value. |
| `test_framework` | **yes** | `kotest-stringspec` | One of: `kotest-stringspec`, `junit5`, `playwright-test`, `jest`, `pytest`, or any free-form value. |
| `source_root` | optional | inferred from `test_dir` | Source-set root above the test package (e.g., `src/test/kotlin`). Used to derive the package name from `test_dir`. Only set explicitly when inference fails. |
| `base_test_class` | optional | auto-detected | Fully-qualified (or simple) name of the base test class that generated tests should extend (e.g., `com.example.qa.BasePageTest`). Written on first disambiguation so future runs don't re-prompt. |

**Required contract:** All four required fields must be present and non-empty in the frontmatter. If any is missing, unparseable, or blank, the file is **malformed** — see the malformed-recovery path below. The optional fields are silently absent by default; absence is not an error.

Currently only `kotlin` + `kotest-stringspec` has a fully wired test-generation path. Other combinations are accepted and persisted, but `/scenario-to-tests` will abort with a clear "unsupported combination" message until their generation rules land.

## Resolution procedure

1. **Check for the file.** Read `.claude/playwright-scenarios.local.md`.

2. **If it exists and the YAML frontmatter parses cleanly with all four required fields present**, return the resolved values. Done — do not prompt, do not rewrite.

3. **If it exists but is malformed** (missing `---` fences, unparseable YAML, any required field missing/blank), stop and return a structured error to the caller:

   ```
   MALFORMED_CONFIG: <specific problem>
   ```

   The caller decides what to do. The normal commands abort and point the user at `/playwright-scenarios-config`. The `/playwright-scenarios-config` command itself has a dedicated malformed-recovery path that does *not* re-enter this skill — it prompts the user to overwrite and writes a fresh file directly.

   Do not silently overwrite from this skill.

4. **If it doesn't exist**, create it via a **three-round interactive bootstrap**. Before prompting, scan the project to inform suggestions. Then ask three rounds: language first, then language-aware directories, then framework.

   a. If `.claude/` does not exist at the repo root, create it.

   b. **Pre-scan the project** to inform suggestions across all three rounds. Run these checks before any prompting:

      - **Detect existing test directories.** Glob for common test roots: `src/test/kotlin/`, `src/test/java/`, `tests/`, `test/`, `src/__tests__/`, `Tests/`. Record which ones exist on disk.
      - **Detect existing scenario-like directories.** Glob for `**/scenarios/`, `**/test-scenarios/`, `**/e2e/`. Record any that already contain `.md` files.
      - **Detect build/config files.** Check for: `build.gradle.kts` or `build.gradle` (JVM/Gradle), `pom.xml` (JVM/Maven), `package.json` (Node.js), `tsconfig.json` (TypeScript), `pyproject.toml` or `setup.py` (Python), `*.csproj` or `*.sln` (.NET). These signal the project's language even before the user answers.
      - **Detect existing test files.** Glob for `**/*Test.kt`, `**/*Test.java`, `**/*.spec.ts`, `**/*.test.ts`, `**/test_*.py`, `**/*_test.py`, `**/*Tests.cs`. This confirms the language and reveals the directory structure the project already uses.
      - **Detect base test classes (JVM only).** Run the base-test-class discovery glob (see "Base test class discovery" below) under any detected JVM source root.

      The scan results don't override the user's choices — they inform the **recommended defaults** and the **order of options** in each round.

   c. **Round 1** — ask two questions in a single `AskUserQuestion` call.

      - **`scenario_dir`** — question: "Where should scenario markdown files live?"
        - If the scan found an existing directory with `.md` scenario files, offer it as the first (Recommended) option.
        - Otherwise, offer `src/test/scenarios` as the default for JVM-detected projects, or `tests/scenarios` for Node.js/Python-detected projects.
        - Always include `scenarios/` (legacy, at repo root) as an alternative.
      - **`test_language`** — question: "What language should generated tests use?"
        - If the scan detected the project language (e.g., found `build.gradle.kts` → suggest `kotlin` first, found `package.json` + `tsconfig.json` → suggest `typescript` first, found `pyproject.toml` → suggest `python` first), order that language as the first (Recommended) option.
        - If the scan found existing test files (e.g., `*.spec.ts`), use that to confirm the suggestion.
        - If the scan couldn't determine the language, present all options in alphabetical order: `.net`, `java`, `javascript`, `kotlin`, `python`, `typescript`.

   d. **Round 2** — now that `test_language` is known, ask `test_dir` with suggestions informed by both the language and the project scan.

      - **If the scan found existing test files in the chosen language**, suggest the directory they're in (or a sibling `scenarios` directory) as the first (Recommended) option.
      - **If no existing tests were found**, fall back to the idiomatic default for the language:

        | `test_language` | Idiomatic default | Alternative |
        |-----------------|-------------------|-------------|
        | `kotlin` | `src/test/kotlin/<package>/scenarios` (from base-test-class if found) | `src/test/kotlin/scenarios` |
        | `java` | `src/test/java/<package>/scenarios` (from base-test-class if found) | `src/test/java/scenarios` |
        | `typescript` | `tests/scenarios` | `src/__tests__/scenarios` |
        | `javascript` | `tests/scenarios` | `src/__tests__/scenarios` |
        | `python` | `tests/scenarios` | `test/scenarios` |
        | `.net` | `Tests/Scenarios` | `tests/scenarios` |

      - For JVM languages, the base-test-class glob searches `src/test/<test_language>/` (not hardcoded `src/test/kotlin/`). If a base test class was found in the pre-scan, suggest a sibling `scenarios` directory in the same package as the Recommended option.
      - If the user picked a `test_language` via "Other" (not one of the known values), skip the suggestion table and ask an open `test_dir` question with free-text only.
      - Always accept "Other" for a custom path.

   e. **Round 3** — ask the framework question with options scoped to the language and informed by the project scan.

      - **If the scan found existing test files that indicate a framework** (e.g., imports of `kotest` in `.kt` files, `@playwright/test` in `.spec.ts` files, `pytest` markers in `.py` files), offer that framework as the first (Recommended) option.
      - **Otherwise**, use the idiomatic default for the language:

        | `test_language` | Options offered (in order) |
        |-----------------|----------------------------|
        | `kotlin` | `kotest-stringspec` (Recommended), `junit5` |
        | `java` | `junit5` (Recommended) |
        | `typescript` | `playwright-test` (Recommended), `jest` |
        | `javascript` | `playwright-test` (Recommended), `jest` |
        | `python` | `pytest` (Recommended) |
        | `.net` | `nunit` (Recommended), `mstest` |

      For languages with a single viable framework, still ask — the user might want to pick "Other" for a framework not in the list. Do not silently assign the default.

      If the user picked a `test_language` via "Other" (not one of the known values), skip the scoped list and ask an open framework question: "What test framework should generated tests use?" with a single "Enter framework" option plus "Other". The `/scenario-to-tests` unsupported-combo guard will handle unknown pairings at generation time.

   f. Write `.claude/playwright-scenarios.local.md` with the four chosen values as YAML frontmatter, followed by the standard markdown body (see "Config file format" above). Do *not* write `source_root` or `base_test_class` at bootstrap — they're added later, only when disambiguation is needed.

   g. **Scaffold the partition subdirectories.** Create the three command-keyed subdirectories under both roots, if they don't already exist:

      - `<scenario_dir>/record/`
      - `<scenario_dir>/crawl/`
      - `<scenario_dir>/convert/`
      - `<test_dir>/record/`
      - `<test_dir>/crawl/`
      - `<test_dir>/convert/`

      Use `mkdir -p` semantics — silent if the directories already exist. Don't drop placeholder files inside; empty directories are fine.

   h. Report the path, the chosen values, and the scaffolded directories to the user in a compact table, then return the four values.

5. **Return the resolved values** to the caller. Callers reference them as `<SCENARIO_DIR>`, `<TEST_DIR>`, `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>` (plus `<SOURCE_ROOT>` and `<BASE_TEST_CLASS>` when set).

## Source-root inference

When `/scenario-to-tests` needs to compute `SCENARIOS_PACKAGE` from `<TEST_DIR>`, it needs the source-set root. Resolution order:

1. If `source_root` is set in the config, use it verbatim.
2. Otherwise, walk `<TEST_DIR>` looking for the longest prefix that matches a known source-set pattern. Try in order: `src/test/kotlin`, `src/test/java`, `src/test/scala`, `src/test/groovy`, `src/test/<TEST_LANGUAGE>`, `test/kotlin`, `test/java`, `test/<TEST_LANGUAGE>`, `tests/<TEST_LANGUAGE>`, `src/test`.
3. On a successful match, **persist** the inferred value by appending `source_root: <value>` to the config file's frontmatter, so future runs skip inference entirely.
4. If no pattern matches, abort with a clear message: "Couldn't infer the source root from `test_dir=<path>`. Add `source_root: <your-source-root>` to `.claude/playwright-scenarios.local.md` and retry."

Callers derive `SCENARIOS_PACKAGE` by stripping the resolved source root (and the trailing `/`) from `<TEST_DIR>` and replacing `/` with `.`.

## Base-test-class discovery

When a command needs to know what class generated tests should extend (currently only `/scenario-to-tests` for the Kotlin + Kotest combo):

1. If `base_test_class` is set in the config, use it verbatim.
2. Otherwise, glob under the resolved source root for abstract classes that look like a Playwright-owning base:
   - File names matching `Base*Test.*`, `*TestBase.*`, `Abstract*Test.*`, `*PageTest.*` (case-insensitive), or
   - Files containing a `StringSpec`/`FunSpec` parent and a `Playwright.create()`/`browser`/`page` member.
3. If exactly one class matches, use it silently — persist it to the config so future runs skip the glob.
4. If multiple match, use `AskUserQuestion` to let the user pick one, then persist the choice.
5. If none match, ask via `AskUserQuestion`: "No base test class found. Scaffold a `BasePageTest` now? (Generated tests need one to extend.)" with options `Yes (Recommended)` / `No`.
   - **Yes**: invoke the `scaffold-base-test` skill with `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>`, `<TEST_DIR>`, `<SOURCE_ROOT>`. Append `base_test_class: <returned_fqn>` to the config frontmatter. Continue with that as the resolved value. Handle skill errors as follows:
     - **`UNSUPPORTED_COMBO`**: print "Scaffolding only supports `kotlin` + `kotest-stringspec`. Generated tests will lack an `extends` clause for now — add one manually or change the language/framework via `/playwright-scenarios-config`." Fall through to the No branch.
     - **`TARGET_EXISTS: <path>`**: a `BasePageTest.kt` already exists at `<path>` but discovery didn't recognize it. Print "Found `<path>` but it doesn't look like a Playwright base test. Either edit it to extend `StringSpec` and own the Playwright lifecycle, or set `base_test_class` directly via `/playwright-scenarios-config`." Fall through to the No branch.
   - **No**: warn that generated tests will lack an `extends` clause; suggest running `/scaffold-base-test` later. Proceed without a base class.

## Gitignore note

The config file is intended to be team-shared (every contributor needs the same scenario location). By default, do not add `.claude/playwright-scenarios.local.md` to `.gitignore`. If the user explicitly asks to keep it personal, they can add that entry themselves.

## What this skill does NOT do

- It does not validate that `test_dir` exists on disk — `/scenario-to-tests` does that at generation time.
- It does not hot-reload — if the user edits the config file mid-session, the calling command must re-invoke this skill to pick up changes.
- It does not infer the build tool or Playwright binding — commands that need those derive them internally from `test_language`.
- It does not recover from malformed config — that's `/playwright-scenarios-config`'s job, via a dedicated path that bypasses this skill.
