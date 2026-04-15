---
name: review-scenario
description: Audit website validation scenarios in the project's scenario directory against the live site and apply improvements to the markdown
arguments:
  - name: scenarios
    description: Zero or more scenario names (without .md extension), space-separated. Zero = all scenarios in the configured scenario directory. One or more = only those specified.
    required: false
---

# Review Scenario

Audit website validation scenarios in `<SCENARIO_DIR>` by checking each scenario's claims against the live site, proposing improvements, and applying them to the scenario `.md` file. This command does **not** generate tests — use `/scenario-to-tests` for that.

## Phase 0: Load project config

Invoke the `loading-config` skill to resolve `<SCENARIO_DIR>`. If `.claude/playwright-scenarios.local.md` is missing, the skill prompts the user and creates it before returning. `<TEST_DIR>`, `<TEST_LANGUAGE>`, and `<TEST_FRAMEWORK>` are not used by this command but will be populated as a side effect of the bootstrap.

## Phase 1: Determine Scenarios

The user may pass zero, one, or multiple scenario names (without `.md` extension), space-separated:

- **Zero arguments:** read all `.md` files **directly inside `<SCENARIO_DIR>`** (non-recursive — do NOT descend into `<SCENARIO_DIR>/drafts/` or any other subdirectory) and review each one. Skip `<SCENARIO_DIR>/SCENARIOS.md` (the hand-maintained index).
- **One or more arguments:** read `<SCENARIO_DIR>/<name>.md` for each name provided and review only those.

For each named scenario, if the file lives under `<SCENARIO_DIR>/drafts/` (or any subdirectory), warn the user that it is a draft and skip it unless the user explicitly overrides. If a named scenario file does not exist, report it and continue with the rest.

## Phase 2: Live-Site Verification (Main Thread)

For each scenario, sequentially:

1. Read the scenario markdown.
2. Open the target URL using the Playwright CLI (via the `playwright-cli` skill).
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

Launch one general-purpose subagent per scenario. Each subagent receives:

- The original scenario markdown
- The findings list from Phase 2 for that scenario
- Up to two existing style-reference scenario files from `<SCENARIO_DIR>` (whichever are present, excluding `SCENARIOS.md` and subdirectories) so the subagent can match the host project's formatting conventions; if none exist, point the subagent at the `authoring-scenarios` skill instead
- Instructions to rewrite the scenario `.md` in place

Subagent rules:

- **Preserve** the original title and URL unless a Phase 2 finding shows they're wrong.
- **Do not delete test cases** — only refine, reword, or add.
- **Fix broken claims** by updating them to match observed behavior.
- **Tighten vague expectations** into concrete, assertable outcomes.
- **Add missing coverage** as new test cases when flagged, but keep additions minimal — one new test per missing-coverage finding.
- **Do not reformat** purely for style unless a finding explicitly flagged style issues.
- **Do not** generate test code or modify any file outside the scenario `.md`.

Subagents write the updated scenario file and return a short summary of what they changed.

## Phase 4: Summary Report (Main Thread)

After all subagents complete, print a per-scenario summary to the user:

- Findings count by severity (e.g., `broken: 1, vague: 2, missing-coverage: 1, style: 0`)
- List of changes applied (e.g., "Test 2: tightened expected outcome", "Added Test 4: empty email case")
- Any findings that were deliberately NOT auto-applied and why (e.g., the review agent was unsure)

Do **not** run any build or test command — that's `/scenario-to-tests`' job.
