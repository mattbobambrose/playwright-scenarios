---
name: loading-config
description: Load per-project configuration for the playwright-scenarios plugin from .claude/playwright-scenarios.local.md. Triggers automatically at the start of any playwright-scenarios command (/record-scenario, /review-scenario, /scenario-to-tests, /playwright-scenarios-config). Prompts the user for the four required fields (scenario_dir, test_dir, test_language, test_framework) on first run and persists them. Additional optional fields (source_root, base_test_class) are auto-inferred when needed and persisted on disambiguation.
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
| `scenario_dir` | **yes** | `src/test/scenarios` | Directory (relative to repo root) where scenario `.md` files live. Non-recursive — subdirectories are treated as drafts. |
| `test_dir` | **yes** | none (must be entered) | Directory (relative to repo root) where generated test files go. |
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

4. **If it doesn't exist**, create it via a **two-round interactive bootstrap**. Splitting the prompts into two rounds lets the framework options in round 2 be constrained to the language picked in round 1, so users never land on an invalid pairing like `typescript` + `kotest-stringspec`.

   a. If `.claude/` does not exist at the repo root, create it.

   b. **Round 1** — ask the three questions that don't depend on each other, in a single `AskUserQuestion` call. Present the default as the first (Recommended) option on each; users can always pick "Other" for a free-form value.

      - **`scenario_dir`** — question: "Where should scenario markdown files live?" Options: `src/test/scenarios` (Recommended — default), `scenarios/` (legacy, at repo root).
      - **`test_dir`** — before prompting, run the base-test-class discovery (see "Base test class discovery" below) to suggest a likely test-output directory. Question: "Where should generated tests go?" Options: the auto-detected path (if any, Recommended), `src/test/kotlin/<package>/scenarios` (generic fallback). Always accept "Other" for a custom path.
      - **`test_language`** — question: "What language should generated tests use?" Options: `kotlin` (Recommended), `java`, `typescript`, `python`.

   c. **Round 2** — now that `test_language` is known, ask the framework question with options scoped to that language. Use a separate `AskUserQuestion` call.

      | `test_language` | Options offered (in order) |
      |-----------------|----------------------------|
      | `kotlin` | `kotest-stringspec` (Recommended), `junit5` |
      | `java` | `junit5` (Recommended) |
      | `typescript` | `playwright-test` (Recommended), `jest` |
      | `python` | `pytest` (Recommended) |

      For languages with a single viable framework (`java`, `python`), still ask — the user might want to pick "Other" for a framework not in the list. Do not silently assign the default.

      If the user picked a `test_language` via "Other" (not one of the four known values), skip the scoped list and ask an open framework question: "What test framework should generated tests use?" with a single "Enter framework" option plus "Other". The `/scenario-to-tests` unsupported-combo guard will handle unknown pairings at generation time.

   d. Write `.claude/playwright-scenarios.local.md` with the four chosen values as YAML frontmatter, followed by the standard markdown body (see "Config file format" above). Do *not* write `source_root` or `base_test_class` at bootstrap — they're added later, only when disambiguation is needed.

   e. Report the path and the chosen values to the user in a compact table, then return the four values.

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
5. If none match, emit a warning and proceed without an `extends` clause. Generated tests will need a manual base-class fix; the warning should say so and suggest setting `base_test_class`.

## Gitignore note

The config file is intended to be team-shared (every contributor needs the same scenario location). By default, do not add `.claude/playwright-scenarios.local.md` to `.gitignore`. If the user explicitly asks to keep it personal, they can add that entry themselves.

## What this skill does NOT do

- It does not validate that `test_dir` exists on disk — `/scenario-to-tests` does that at generation time.
- It does not hot-reload — if the user edits the config file mid-session, the calling command must re-invoke this skill to pick up changes.
- It does not infer the build tool or Playwright binding — commands that need those derive them internally from `test_language`.
- It does not recover from malformed config — that's `/playwright-scenarios-config`'s job, via a dedicated path that bypasses this skill.
