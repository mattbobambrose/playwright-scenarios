---
name: scenario-to-tests
description: Generate tests in the project's configured language and framework from website validation scenarios. Assumes scenarios have already been reviewed.
arguments:
  - name: scenarios
    description: Zero or more scenario names (without .md extension), space-separated, optionally mixed with flags. Zero scenarios = all scenarios in the configured scenario directory. Supported flags - --include-drafts (process files under <SCENARIO_DIR>/drafts/ and other subdirectories), --dry-run (skip Phase 4 test execution).
    required: false
---

# Scenario To Tests

> If you want to first audit a scenario against the live site, use `/review-scenario` before running this.

## Argument parsing

Before Phase 0, split the argument string into **flags** (tokens starting with `--`) and **names** (everything else):

- `--include-drafts` — also process scenario files living under subdirectories (e.g. `<SCENARIO_DIR>/drafts/`). Off by default.
- `--dry-run` — write the test files in Phase 3 but skip the Phase 4 test run.

Any unknown `--`-prefixed token should be reported as an error before doing any work.

## Phase 0: Load project config and preflight

### 0a. Load config

Invoke the `loading-config` skill to resolve the four required config values:

- **`<SCENARIO_DIR>`** — where input scenario `.md` files live.
- **`<TEST_DIR>`** — where generated test files go.
- **`<TEST_LANGUAGE>`** — drives the file extension and syntax.
- **`<TEST_FRAMEWORK>`** — drives the test shape (class, decorators, imports).

The skill may also return `<SOURCE_ROOT>` and `<BASE_TEST_CLASS>` if they were explicitly set in the config. If `loading-config` returns `MALFORMED_CONFIG`, abort with that message and tell the user to run `/playwright-scenarios-config` to repair.

### 0b. Unsupported-combo guard

If `<TEST_LANGUAGE>` is not `kotlin` **or** `<TEST_FRAMEWORK>` is not `kotest-stringspec`, stop with a clear message:

> Test generation currently supports `kotlin` + `kotest-stringspec` only. Your config says `<TEST_LANGUAGE>` + `<TEST_FRAMEWORK>`. Edit `.claude/playwright-scenarios.local.md` or run `/playwright-scenarios-config` to change it, or open an issue asking for `<TEST_LANGUAGE>`/`<TEST_FRAMEWORK>` support.

Do not write any files.

### 0c. Resolve `SCENARIOS_PACKAGE`

Follow the "Source-root inference" procedure in the `loading-config` skill to obtain `<SOURCE_ROOT>` (uses the config value if set, otherwise pattern-matches `<TEST_DIR>` against known source-set prefixes, aborting if nothing matches).

`SCENARIOS_PACKAGE` = `<TEST_DIR>` with the resolved source root stripped, trailing/leading slashes removed, `/` replaced by `.`. Example: `src/test/kotlin/com/example/qa/scenarios` with source root `src/test/kotlin` → `com.example.qa.scenarios`.

### 0d. Resolve `BASE_TEST_CLASS`

Follow the "Base-test-class discovery" procedure in the `loading-config` skill (uses the config value if set, otherwise globs for candidates, prompts on ambiguity, and persists the choice). Both `source_root` and `base_test_class` are persisted to the config after first successful resolution so future runs skip inference entirely.

`BASE_PACKAGE` = the package portion of `BASE_TEST_CLASS`, or empty if none.

### 0e. `playwright-cli` preflight

Phase 2 shells out to `playwright-cli` via the skill of the same name. Verify it's callable *now* so the user isn't stopped mid-recording:

1. Run `playwright-cli --version` (timeout: 5s). If it succeeds, record that the global binary works.
2. If it fails, run `npx --no-install playwright-cli --version`. If that succeeds, record that `npx playwright-cli` should be used.
3. If both fail, abort with:
   > `playwright-cli` is not available. Install it with `npm install -g @playwright/cli@latest` or make sure `npx playwright-cli` works in this project. See the README's "Host Project Setup" section for details.

## Phase 1: Select scenario files

Using the scenario names parsed from the argument-parsing step:

- **Zero scenario names:** read all `.md` files **directly inside `<SCENARIO_DIR>`** (non-recursive — do NOT descend into `<SCENARIO_DIR>/drafts/` or any other subdirectory, unless `--include-drafts` was passed) and process each one. Skip `<SCENARIO_DIR>/SCENARIOS.md`.
- **One or more scenario names:** read `<SCENARIO_DIR>/<name>.md` for each. If a named scenario file is not found directly under `<SCENARIO_DIR>`, also check `<SCENARIO_DIR>/**/<name>.md` — if it's under a subdirectory and `--include-drafts` was not passed, warn and skip. With `--include-drafts`, include it.

If a named scenario file does not exist anywhere under `<SCENARIO_DIR>`, report it and continue with the rest.

If the final list is empty (no scenarios found, or all were drafts and `--include-drafts` was not passed), report that clearly and stop — do not proceed to Phase 2 with no work to do.

## Phase 2: Browser Exploration (Main Thread)

For each scenario, sequentially:

1. Read the scenario file from its resolved path
2. Open the target URL using the Playwright CLI (via the `playwright-cli` skill, using whichever invocation the preflight in step 0e confirmed works)
3. Perform each test case interactively, observing actual behavior and error messages
4. Record observations: exact error messages, element selectors, page URLs, and any unexpected behavior
5. Save any screenshots to `screenshots/` directory (e.g., `screenshots/scenario-name-test1.png`)

Collect all observations before moving to Phase 3.

## Phase 3: Test Generation (Parallel Subagents)

Launch subagents in **batches of at most 5 concurrent** to avoid overwhelming the harness. If there are more than 5 scenarios, process them in sequential batches; if 5 or fewer, launch them all in one batch.

Each subagent receives:

- The scenario file content
- The browser observations collected in Phase 2
- The resolved config values (`<TEST_DIR>`, `SCENARIOS_PACKAGE`, `BASE_TEST_CLASS`, `BASE_PACKAGE`, `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>`)
- The test generation rules below (including the scenario-name → class-name conversion rules)

Subagents write the test file but do NOT run the build tool.

## Phase 4: Run All Tests (Main Thread)

Skip this phase entirely if `--dry-run` was passed; report the list of generated files and stop.

Otherwise, run the project's test command:

- **If the user named specific scenarios**, target those test classes explicitly — one `--tests` flag per class. For example, scenarios `login-invalid-credentials` and `email-signup-form` with `SCENARIOS_PACKAGE = com.example.qa.scenarios` become:

  ```
  ./gradlew test --tests "com.example.qa.scenarios.LoginInvalidCredentialsTest" --tests "com.example.qa.scenarios.EmailSignupFormTest"
  ```

- **If zero scenario names were passed** (all scenarios), target the whole scenarios package:

  ```
  ./gradlew test --tests "<SCENARIOS_PACKAGE>.*"
  ```

  (e.g. `--tests "com.example.qa.scenarios.*"`)

If any tests fail, fix them sequentially and re-run.

## Test Generation Rules

These rules apply to the currently supported combo (`kotlin` + `kotest-stringspec`). When additional combos are wired up, each will have its own rule set below.

### Scenario-name → class-name conversion

Apply this transformation to every scenario filename to produce the Kotlin class name. This is the single source of truth — subagents and the Phase 4 test-targeting logic must use identical output.

1. Drop the `.md` extension.
2. Treat hyphens (`-`), underscores (`_`), and periods (`.`) as word separators.
3. Drop any character that is not `[A-Za-z0-9]` (everything else is a separator or discarded).
4. Title-case each word: uppercase the first character, lowercase the rest.
5. Concatenate the words with no separator.
6. If the result starts with a digit, prefix with `_` so it's a valid Kotlin identifier.
7. Append `Test`.

Examples:

| Scenario filename | Class name |
|-------------------|------------|
| `login-invalid-credentials.md` | `LoginInvalidCredentialsTest` |
| `email_signup_form.md` | `EmailSignupFormTest` |
| `2fa-setup.md` | `_2faSetupTest` |
| `signup.md` | `SignupTest` |
| `user-signup-v2.md` | `UserSignupV2Test` |
| `book.search.filters.md` | `BookSearchFiltersTest` |

The filename for the generated Kotlin file is `<ClassName>.kt`.

### `kotlin` + `kotest-stringspec`

- Use Kotest with **StringSpec** style and an **`init`** block.
- Extend `BASE_TEST_CLASS` if one was resolved in step 0d. If `BASE_TEST_CLASS` is empty, omit the `extends` clause and add a TODO comment at the top of the file flagging that the user needs to supply a base class.
- Declare the class in `SCENARIOS_PACKAGE`.
- Write the test file to `<TEST_DIR>/<ClassName>.kt`, creating the directory tree if it doesn't exist.

### Extended tag handling

Scenarios may use extended tags (documented in the `authoring-scenarios` skill). Handle them as follows:

- **`**Fixture:** <path>`** — Import the fixture file and use its factory function for test data instead of inlining values. If the fixture file doesn't exist yet, inline the values and note it in the output.
- **`**Prerequisite:** <scenario-name> (Tests N-M)`** — Read the referenced scenario and generate setup code that runs the referenced tests' flow. Emit this as either a `beforeAll`-equivalent setup block or as the first test in the `init` block (since Kotest StringSpec tests share page state sequentially). The prerequisite flow runs once, and subsequent tests assert against the resulting page state.
- **`**Assert throughout:** <assertion>`** — Register a page-level listener at the start of the flow (e.g. `page.on("console", ...)` for console error capture) and assert at the end of the last test. For "No application JS console errors", filter out "Failed to load resource" messages (browser-generated network noise).
- **`**Expected failure:** <reason>`** — The test should be annotated to expect failure. In Kotest, wrap the assertion body so that a failing assertion is the expected outcome. Include a comment with the reason so maintainers know why.
- **`**Expected (regex):** <pattern>`** — Generate a regex assertion (`shouldMatch`, `Regex(...).containsMatchIn(...)`) instead of an exact substring check (`shouldContain`).
