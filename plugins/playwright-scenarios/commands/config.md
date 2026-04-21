---
name: playwright-scenarios-config
description: View or update the playwright-scenarios per-project settings stored in .claude/playwright-scenarios.local.md. Also the recovery path when that file is malformed.
---

# Playwright Scenarios Config

Explicitly view and update the fields the `playwright-scenarios` plugin reads before every command: `scenario_dir`, `test_dir`, `test_language`, `test_framework`, and (optionally) `source_root`, `base_test_class`. The normal commands auto-prompt for the required four on first use — run this command when you want to *change* them afterwards, or when `.claude/playwright-scenarios.local.md` is malformed and other commands are refusing to load it.

## Phases

### Phase 1: Probe the config file directly

Do **not** start by invoking the `loading-config` skill — if the file is malformed the skill returns `MALFORMED_CONFIG: ...` and bounces back here, creating a loop. Instead, read `.claude/playwright-scenarios.local.md` yourself and branch:

- **File does not exist** → invoke the `loading-config` skill to run the normal interactive bootstrap. The skill writes the file and returns; this command is done and can skip to Phase 5.
- **File exists and parses cleanly** (all four required fields present and non-empty) → continue to Phase 2.
- **File exists but is malformed** (missing `---` fences, unparseable YAML, any required field missing or blank) → go to Phase 1a (malformed-recovery).

#### Phase 1a: Malformed-recovery path

1. Print the existing file content to the user (wrapped in a code block) along with a one-line diagnosis of what's wrong (e.g., "`test_language` is missing" or "closing `---` fence not found").
2. Use `AskUserQuestion` to confirm: "Overwrite `.claude/playwright-scenarios.local.md` with fresh config?" Options: `Yes, overwrite` (Recommended), `No, I'll fix it by hand`.
3. If the user chose to fix it by hand, stop and report the diagnosis. Do not overwrite.
4. If the user chose to overwrite, invoke the `loading-config` skill with the expectation that the file is gone — but the skill checks for existence, so first **delete the file** (or rename it to `.claude/playwright-scenarios.local.md.bak` for safety) before invoking the skill. After the skill bootstraps a fresh file, report success and stop; this command is done.

### Phase 2: Show current config

If Phase 1 produced a cleanly-parsed config, show the user a compact table of the current values:

```
| Field            | Value                                             |
|------------------|---------------------------------------------------|
| scenario_dir     | src/test/scenarios                                |
| test_dir         | src/test/kotlin/com/example/qa/scenarios          |
| test_language    | kotlin                                            |
| test_framework   | kotest-stringspec                                 |
| source_root      | (inferred)                                        |
| base_test_class  | (auto-detect)                                     |
```

For the optional fields, show the literal YAML value if set, or `(inferred)` / `(auto-detect)` if absent.

### Phase 3: Re-prompt each field (three rounds)

Mirror the `loading-config` skill's three-round pattern. Before prompting, run the same project pre-scan described in `loading-config` step 4b (detect existing test directories, build/config files, test files, and base test classes) so suggestions reflect the project's current state — not just the stored config.

**Round 1** — one `AskUserQuestion` call with two questions: `scenario_dir` and `test_language`. Pre-fill the *current* value as the first (Recommended) option for each. If the project scan detected a language or an existing scenario directory that differs from the stored value, include it as a second option with a note (e.g., "Detected from project: `typescript`"). Users who want to keep a value untouched just pick the first option.

**Round 2** — after round 1 resolves, issue a second `AskUserQuestion` call asking `test_dir`. Suggestions are informed by both the language chosen in round 1 and what the project scan found on disk (see the language→test_dir table and project-scan logic in `loading-config`). If the language changed and the current `test_dir` doesn't match the new language's conventions, use the scan-informed or idiomatic default as the first option and note in the question that the directory suggestion is changing because the language changed. If the language didn't change, pre-fill the current `test_dir` as the first option.

**Round 3** — issue a third `AskUserQuestion` call asking only `test_framework`. If the project scan detected a framework from existing test files, offer it as the first option. Otherwise, options are scoped to the `test_language` chosen in round 1 (see the language→framework table in `loading-config`). If the current `test_framework` is valid for the new language, pre-fill it as the first (Recommended) option; otherwise, use the detected or idiomatic default and note that the framework is being reset because the language changed.

Do not prompt for `source_root` or `base_test_class`. Those are advanced overrides — users who need them edit the YAML by hand. This command preserves their existing values if set.

### Phase 4: Write the file

Rewrite the YAML frontmatter in `.claude/playwright-scenarios.local.md` with the new values.

- The four required fields always go in the frontmatter.
- The optional fields (`source_root`, `base_test_class`) go in the frontmatter **only if they were present in the original file**. Preserve them verbatim; don't drop or add them.
- **Preserve any hand-written markdown body** below the frontmatter — users sometimes add project-specific notes there. Only the frontmatter block (between the two `---` fences) is managed by this command.

If the file didn't exist before Phase 1 (bootstrap case), the `loading-config` skill already wrote a fresh file; just confirm the write and stop.

### Phase 5: Report

List which fields changed (e.g., `scenario_dir: scenarios/ → src/test/scenarios`), or report "No changes — config unchanged" if every selected value matched the prior one. Do not suggest re-running other commands; the user knows what they came here to change.
