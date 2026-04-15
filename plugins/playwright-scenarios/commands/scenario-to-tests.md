---
name: scenario-to-tests
description: Generate tests in the project's configured language and framework from website validation scenarios. Assumes scenarios have already been reviewed.
arguments:
  - name: scenarios
    description: Zero or more scenario names (without .md extension), space-separated. Zero = all scenarios in the configured scenario directory. One or more = only those specified.
    required: false
---

# Scenario To Tests

> If you want to first audit a scenario against the live site, use `/review-scenario` before running this.

## Phase 0: Load project config

Invoke the `loading-config` skill to resolve the four config values:

- **`<SCENARIO_DIR>`** — where input scenario `.md` files live.
- **`<TEST_DIR>`** — where generated test files go. Used below as `SCENARIOS_DIR`.
- **`<TEST_LANGUAGE>`** — drives the file extension and syntax.
- **`<TEST_FRAMEWORK>`** — drives the test shape (class, decorators, imports).

Derive two more values from the config:

- **`SCENARIOS_PACKAGE`** — for JVM languages, strip the leading `src/test/<lang>/` from `<TEST_DIR>` and replace `/` with `.`. Example: `src/test/kotlin/com/example/qa/scenarios` → `com.example.qa.scenarios`. For non-JVM languages this value is unused.
- **`BASE_PACKAGE`** — for JVM languages, the package containing the project's base test class. Locate by globbing inside and adjacent to `<TEST_DIR>` for a class that matches the project's base-test pattern (e.g., `BasePageTest`, `BaseTest`, `BasePage`). If none is found, fall back to treating `SCENARIOS_PACKAGE`'s parent as `BASE_PACKAGE` and warn the user — the emitted test file will need a manual `extends` fix.

### Unsupported-combo guard

If `<TEST_LANGUAGE>` is not `kotlin` **or** `<TEST_FRAMEWORK>` is not `kotest-stringspec`, stop with a clear message:

> Test generation currently supports `kotlin` + `kotest-stringspec` only. Your config says `<TEST_LANGUAGE>` + `<TEST_FRAMEWORK>`. Edit `.claude/playwright-scenarios.local.md` or run `/playwright-scenarios-config` to change it, or open an issue asking for `<TEST_LANGUAGE>`/`<TEST_FRAMEWORK>` support.

Do not write any files.

## Phase 1: Determine Scenarios

The user may pass zero, one, or multiple scenario names (without `.md` extension), space-separated:

- **Zero arguments:** read all `.md` files **directly inside `<SCENARIO_DIR>`** (non-recursive — do NOT descend into `<SCENARIO_DIR>/drafts/` or any other subdirectory) and process each one.
- **One or more arguments:** read `<SCENARIO_DIR>/<name>.md` for each name provided and process only those.

For each named scenario, if the file lives under `<SCENARIO_DIR>/drafts/` (or any subdirectory), warn the user that it is a draft and skip it unless the user explicitly overrides. If a named scenario file does not exist, report it and continue with the rest.

## Phase 2: Browser Exploration (Main Thread)

For each scenario, sequentially:

1. Read the scenario file from `<SCENARIO_DIR>`
2. Open the target URL using the Playwright CLI (via the `playwright-cli` skill)
3. Perform each test case interactively, observing actual behavior and error messages
4. Record observations: exact error messages, element selectors, page URLs, and any unexpected behavior
5. Save any screenshots to `screenshots/` directory (e.g., `screenshots/scenario-name-test1.png`)

Collect all observations before moving to Phase 3.

## Phase 3: Test Generation (Parallel Subagents)

Launch one subagent per scenario to write the test file. Each subagent receives:

- The scenario file content
- The browser observations collected in Phase 2
- The resolved config values (`<TEST_DIR>`, `SCENARIOS_PACKAGE`, `BASE_PACKAGE`, `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>`)
- The test generation rules below

Subagents write the test file but do NOT run the build tool.

## Phase 4: Run All Tests (Main Thread)

After all subagents complete, run the project's test command:

- **If the user named specific scenarios**, target those test classes explicitly — one `--tests` flag per class. For example, scenarios `login-invalid-credentials` and `email-signup-form` with `SCENARIOS_PACKAGE = com.example.qa.scenarios` become:

  ```
  ./gradlew test --tests "com.example.qa.scenarios.LoginInvalidCredentialsTest" --tests "com.example.qa.scenarios.EmailSignupFormTest"
  ```

- **If zero arguments were passed** (all scenarios), target the whole scenarios package:

  ```
  ./gradlew test --tests "<SCENARIOS_PACKAGE>.*"
  ```

  (e.g. `--tests "com.example.qa.scenarios.*"`)

If any tests fail, fix them sequentially and re-run.

## Test Generation Rules

These rules apply to the currently supported combo (`kotlin` + `kotest-stringspec`). When additional combos are wired up, each will have its own rule set below.

### `kotlin` + `kotest-stringspec`

- Use Kotest with **StringSpec** style and an **`init`** block.
- Extend the base test class from `BASE_PACKAGE` (typically `BasePageTest`).
- Declare the class in `SCENARIOS_PACKAGE`.
- Name the test class after the scenario file (e.g., `login-invalid-credentials.md` → `LoginInvalidCredentialsTest`).
- Write the test file to `<TEST_DIR>`, creating the directory tree if it doesn't exist.
