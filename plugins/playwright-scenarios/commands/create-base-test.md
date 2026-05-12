---
name: create-base-test
description: Create a Kotlin BasePageTest class into the consuming project so generated tests have a base class to extend. Currently supports kotlin + kotest-stringspec only. Writes a single .kt file at the parent of <test_dir> and persists base_test_class in the config. Refuses to overwrite an existing file.
summary: Generate a Kotlin `BasePageTest` so generated tests have a base class to extend. Prompts for `/reset` endpoint, lifecycle scope, and browser. Persists `base_test_class` in the config. Currently `kotlin` + `kotest-stringspec` only. Auto-offered by `loading-config` when no base class is found in the project.
signature: /create-base-test
---

# Create Base Test

Generate a Kotlin + Kotest `BasePageTest` for the current project. Run this once per project; subsequent runs of `/scenario-to-tests` pick up the persisted `base_test_class` from the config. Most users hit this skill indirectly through `loading-config`'s auto-offer; run the command explicitly only when (re)generating the file.

## Phase 0: Load config

Invoke the `loading-config` skill. From its return, take `<TEST_LANGUAGE>`, `<TEST_FRAMEWORK>`, `<TEST_DIR>`, `<SOURCE_ROOT>`, and the current `<BASE_TEST_CLASS>`. If it returns `MALFORMED_CONFIG`, abort with that message and tell the user to run `/playwright-scenarios-config` to repair.

## Phase 1: Already-configured guard

If `<BASE_TEST_CLASS>` is non-empty, stop with:

> `base_test_class` is already set to `<BASE_TEST_CLASS>` in `.claude/playwright-scenarios.local.md`. To regenerate, remove that line from the config (or run `/playwright-scenarios-config`), then re-run this command.

## Phase 2: Hand off to the skill

Invoke the `create-base-test` skill with the four resolved values from Phase 0. The skill prompts the user, renders the template, writes the file, and returns `{fqn, target_file, choices}`.

If the skill returns an error code, surface a user-facing message and stop without editing the config:

- `UNSUPPORTED_COMBO: <lang> + <framework>` →
  > Creation currently supports `kotlin` + `kotest-stringspec` only. Your config says `<lang>` + `<framework>`. Run `/playwright-scenarios-config` to change it, or open an issue requesting support.
- `TARGET_EXISTS: <path>` →
  > A `BasePageTest.kt` already exists at `<path>`. Delete it first to regenerate, or run `/playwright-scenarios-config` to point `base_test_class` at it.

## Phase 3: Persist `base_test_class`

Read `.claude/playwright-scenarios.local.md`. Inside the YAML frontmatter, append `base_test_class: <fqn>` after the existing required fields. Preserve every other line in the frontmatter and the entire markdown body verbatim.

## Phase 4: Report

```
✓ Created BasePageTest at <target_file>
  FQN: <fqn>  (reset=<…>, lifecycle=<…>, browser=<…>)
✓ Persisted base_test_class in .claude/playwright-scenarios.local.md

Run /scenario-to-tests next; generated tests will extend <fqn>.
```
