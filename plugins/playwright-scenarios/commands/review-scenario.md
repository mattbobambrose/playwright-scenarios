---
name: review-scenario
description: Audit website validation scenarios in the project's scenario directory against the live site and apply improvements to the markdown
arguments:
  - name: scenarios
    description: Zero or more scenario names (without .md extension), space-separated, optionally mixed with flags. Zero scenarios = all scenarios in the configured scenario directory. Supported flag - --include-drafts (review files under <SCENARIO_DIR>/drafts/ and other subdirectories).
    required: false
---

# Review Scenario

Audit website validation scenarios in `<SCENARIO_DIR>` by checking each scenario's claims against the live site, proposing improvements, and applying them to the scenario `.md` file. This command does **not** generate tests — use `/scenario-to-tests` for that.

## Argument parsing

Before Phase 0, split the argument string into **flags** (tokens starting with `--`) and **names** (everything else):

- `--include-drafts` — also review scenario files living under subdirectories (e.g. `<SCENARIO_DIR>/drafts/`). Off by default.

Any unknown `--`-prefixed token should be reported as an error before doing any work.

## Phase 0: Load project config and preflight

### 0a. Load config

Invoke the `loading-config` skill to resolve `<SCENARIO_DIR>`. If `.claude/playwright-scenarios.local.md` is missing, the skill prompts the user and creates it before returning. If the skill returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair. `<TEST_DIR>`, `<TEST_LANGUAGE>`, and `<TEST_FRAMEWORK>` are not used by this command but will be populated as a side effect of the bootstrap.

### 0b. `playwright-cli` preflight

Phase 2 shells out to `playwright-cli` via the skill of the same name. Verify it's callable *now* so the user isn't stopped mid-review:

1. Run `playwright-cli --version` (timeout: 5s). If it succeeds, record that the global binary works.
2. If it fails, run `npx --no-install playwright-cli --version`. If that succeeds, record that `npx playwright-cli` should be used.
3. If both fail, abort with:
   > `playwright-cli` is not available. Install it with `npm install -g @playwright/cli@latest` or make sure `npx playwright-cli` works in this project. See the README's "Host Project Setup" section for details.

## Phase 1: Select scenario files

Using the scenario names parsed from the argument-parsing step:

- **Zero scenario names:** read all `.md` files **directly inside `<SCENARIO_DIR>`** (non-recursive — do NOT descend into `<SCENARIO_DIR>/drafts/` or any other subdirectory unless `--include-drafts` was passed) and review each one. Skip `<SCENARIO_DIR>/SCENARIOS.md` (the hand-maintained index).
- **One or more scenario names:** read `<SCENARIO_DIR>/<name>.md` for each. If a named scenario file is not found directly under `<SCENARIO_DIR>`, also check `<SCENARIO_DIR>/**/<name>.md` — if it's under a subdirectory and `--include-drafts` was not passed, warn and skip. With `--include-drafts`, include it.

If a named scenario file does not exist anywhere under `<SCENARIO_DIR>`, report it and continue with the rest.

If the final list is empty (all drafts skipped, or empty scenarios directory), report that and stop — don't proceed to Phase 2 with no work to do.

## Phase 2: Live-Site Verification (Main Thread)

For each scenario, sequentially:

1. Read the scenario markdown.
2. Open the target URL using the Playwright CLI (via the `playwright-cli` skill, using whichever invocation the preflight in step 0b confirmed works).
3. For each test case in the scenario, walk through the described steps and record what actually happens:
   - Does the URL still load? Any redirects?
   - Do referenced elements/selectors exist? Are the descriptions accurate?
   - Do observed behaviors match the stated expectations?
   - Are there edge cases the scenario doesn't cover but a reasonable reader would expect (empty input, invalid input, viewport variants for responsive pages, etc.)?
4. Collect observations into a structured finding list per scenario, tagged by severity:
   - **broken** — scenario claim does not match reality (wrong URL, missing element, wrong expected text)
   - **vague** — expected outcome is too fuzzy to assert (e.g., "works correctly")
   - **missing-coverage** — obvious case the scenario should include
   - **style** — inconsistent formatting vs other scenarios in the directory

Collect all findings before moving to Phase 3.

## Phase 3: Improvement Generation + Auto-Apply (Parallel Subagents)

Launch subagents in **batches of at most 5 concurrent** to avoid overwhelming the harness. If there are more than 5 scenarios, process them in sequential batches of up to 5; if 5 or fewer, launch them all in one batch.

Each subagent receives:

- The original scenario markdown
- The findings list from Phase 2 for that scenario
- Up to two existing style-reference scenario files from `<SCENARIO_DIR>` (whichever are present, excluding `SCENARIOS.md` and subdirectories) so the subagent can match the host project's formatting conventions; if none exist, point the subagent at the `authoring-scenarios` skill instead
- Instructions to rewrite the scenario `.md` in place

Subagent rules:

- **Preserve** the original title and URL unless a Phase 2 finding shows they're wrong.
- **Preserve extended tags** (`**Fixture:**`, `**Prerequisite:**`, `**Assert throughout:**`, `**Expected failure:**`, `**Expected (regex):**`, `**Iframe:**`, `**Branch:**`, `**Intercept:**`, `**Cookie:**`, `**Storage:**`, `**Device:**`, `**Timeout:**`, `**Cleanup:**`) — these are intentional. Do not remove or rewrite them unless a finding shows they're wrong.
- **Do not delete test cases** — only refine, reword, or add.
- **Fix broken claims** by updating them to match observed behavior.
- **Tighten vague expectations** into concrete, assertable outcomes.
- **Add missing coverage** as new test cases when flagged, but keep additions minimal — one new test per missing-coverage finding.
- **Do not reformat** purely for style unless a finding explicitly flagged style issues.
- **Do not** generate test code or modify any file outside the scenario `.md`.

Subagents write the updated scenario file and return a short summary of what they changed.

## Phase 4: Summary Report (Main Thread)

After all batches complete, print a per-scenario summary to the user as a table:

| Scenario | Findings (by severity) | Changes applied | Skipped findings |
|----------|------------------------|-----------------|------------------|

- Findings count by severity (e.g., `broken: 1, vague: 2, missing-coverage: 1, style: 0`)
- List of changes applied (e.g., "Test 2: tightened expected outcome", "Added Test 4: empty email case")
- Any findings that were deliberately NOT auto-applied and why (e.g., the review agent was unsure)

Do **not** run any build or test command — that's `/scenario-to-tests`' job.
