---
name: loading-config
description: Load per-project configuration for the playwright-scenarios plugin from .claude/playwright-scenarios.local.md. Triggers automatically at the start of any playwright-scenarios command (/record-scenario, /review-scenario, /scenario-to-tests, /playwright-scenarios-config). Prompts the user for the four required fields (scenario_dir, test_dir, test_language, test_framework) on first run and persists them.
---

# Loading Plugin Configuration

The `playwright-scenarios` plugin stores per-project settings in `.claude/playwright-scenarios.local.md` at the repo root. This skill resolves that config and returns four values that the rest of the plugin consumes: `SCENARIO_DIR`, `TEST_DIR`, `TEST_LANGUAGE`, `TEST_FRAMEWORK`.

## Config file format

YAML frontmatter followed by a markdown body. Only the frontmatter is load-bearing; the body is free-form notes for humans.

```markdown
---
scenario_dir: src/test/scenarios
test_dir: src/test/kotlin/com/example/qa/scenarios
test_language: kotlin
test_framework: kotest-stringspec
---

# Playwright Scenarios — Project Config

Edit the YAML frontmatter to reconfigure, or run `/playwright-scenarios-config` to re-prompt.
```

### Field semantics

| Field | Required | Default offered | Purpose |
|-------|----------|-----------------|---------|
| `scenario_dir` | yes | `src/test/scenarios` | Directory (relative to repo root) where scenario `.md` files live. Non-recursive — subdirectories are treated as drafts. |
| `test_dir` | yes | none (must be entered) | Directory (relative to repo root) where generated test files go. |
| `test_language` | yes | `kotlin` | One of: `kotlin`, `java`, `typescript`, `python`. |
| `test_framework` | yes | `kotest-stringspec` | One of: `kotest-stringspec`, `junit5`, `playwright-test`, `jest`, `pytest`. |

Currently only `kotlin` + `kotest-stringspec` has a fully wired test-generation path. Other combinations are accepted and persisted, but `/scenario-to-tests` will abort with a clear "unsupported combination" message until their generation rules land.

## Resolution procedure

1. **Check for the file.** Read `.claude/playwright-scenarios.local.md`.

2. **If it exists and the YAML frontmatter parses cleanly**, return the four field values. Done — do not prompt, do not rewrite.

3. **If it exists but is malformed** (missing `---` fences, unparseable YAML, missing required fields), stop immediately and report:
   > `.claude/playwright-scenarios.local.md` is malformed: <specific problem>. Edit the file directly or run `/playwright-scenarios-config` to recreate it.
   Do not silently overwrite.

4. **If it doesn't exist**, create it via an interactive bootstrap:

   a. If `.claude/` does not exist at the repo root, create it.

   b. Use `AskUserQuestion` to prompt for each field, in this order. Present the default as the first (Recommended) option. Users can always pick "Other" for a free-form value.

      - **`scenario_dir`** — question: "Where should scenario markdown files live?" Options: `src/test/scenarios` (Recommended — default), `scenarios/` (legacy, at repo root).
      - **`test_dir`** — before prompting, Glob for `**/BasePageTest.*` (or `**/BaseTest.*`, `**/BasePage.*`) under `src/test/` to auto-suggest a sibling `scenarios` package. Question: "Where should generated tests go?" Options: the auto-detected path (if any, Recommended), `src/test/kotlin/<package>/scenarios` (generic fallback). Always accept "Other" for a custom path.
      - **`test_language`** — question: "What language should generated tests use?" Options: `kotlin` (Recommended), `java`, `typescript`, `python`.
      - **`test_framework`** — question: "What test framework should generated tests use?" Options depend on language: Kotlin → `kotest-stringspec` (Recommended), `junit5`. Java → `junit5` (Recommended). TypeScript → `playwright-test` (Recommended), `jest`. Python → `pytest` (Recommended).

   c. Write `.claude/playwright-scenarios.local.md` with the chosen values as YAML frontmatter, followed by the standard markdown body (see "Config file format" above).

   d. Report the path and the chosen values to the user in a compact table, then return the four values.

5. **Return the resolved values** to the caller. Callers reference them as `<SCENARIO_DIR>`, `<TEST_DIR>`, `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>`.

## Gitignore note

The config file is intended to be team-shared (every contributor needs the same scenario location). By default, do not add `.claude/playwright-scenarios.local.md` to `.gitignore`. If the user explicitly asks to keep it personal, they can add that entry themselves.

## What this skill does NOT do

- It does not validate that `test_dir` exists on disk — `/scenario-to-tests` does that at generation time.
- It does not hot-reload — if the user edits the config file mid-session, the calling command must re-invoke this skill to pick up changes.
- It does not infer the build tool or Playwright binding — commands that need those derive them internally from `test_language`.
