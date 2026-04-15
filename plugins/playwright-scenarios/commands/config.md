---
name: playwright-scenarios-config
description: View or update the playwright-scenarios per-project settings stored in .claude/playwright-scenarios.local.md
---

# Playwright Scenarios Config

Explicitly view and update the four fields that the `playwright-scenarios` plugin reads before every command: `scenario_dir`, `test_dir`, `test_language`, `test_framework`. The normal commands (`/record-scenario`, `/review-scenario`, `/scenario-to-tests`) auto-prompt for these on first use — run this command whenever you want to *change* them afterwards.

## Steps

### 1. Load and display current config

Invoke the `loading-config` skill. If `.claude/playwright-scenarios.local.md` already exists, the skill returns the four values without prompting; if it's missing, the skill will bootstrap it interactively — in that case this command has already done its job and can skip to step 4.

If the config did exist, show the user a compact table of the current values:

```
| Field            | Value                                             |
|------------------|---------------------------------------------------|
| scenario_dir     | src/test/scenarios                                |
| test_dir         | src/test/kotlin/com/example/qa/scenarios          |
| test_language    | kotlin                                            |
| test_framework   | kotest-stringspec                                 |
```

### 2. Re-prompt each field

Use `AskUserQuestion` to re-ask each of the four fields. Pre-fill the *current* value as the first (Recommended) option, followed by the `loading-config` skill's standard alternatives. Users who want to keep a value untouched just pick the first option.

Batch the four questions into a single `AskUserQuestion` call if possible — they're independent and multi-question prompts are less disruptive than sequential ones.

### 3. Write the file

Replace the YAML frontmatter in `.claude/playwright-scenarios.local.md` with the new values.

**Preserve any hand-written markdown body** below the frontmatter — users sometimes add project-specific notes there. Only the frontmatter block (between the two `---` fences) is managed by this command.

If the file didn't exist before step 1 (bootstrap case), the `loading-config` skill already wrote a fresh file with the standard body; just confirm the write and stop.

### 4. Report

List which fields changed (e.g., `scenario_dir: scenarios/ → src/test/scenarios`), or report "No changes — config unchanged" if every selected value matched the prior one. Do not suggest re-running other commands; the user knows what they came here to change.
