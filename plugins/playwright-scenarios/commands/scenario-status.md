---
name: scenario-status
description: Display a health dashboard for all scenarios — last reviewed, test file existence, test pass/fail status, and coverage gaps vs. site inventory. Use when the user asks "what's the status of my scenarios?" or "what's stale/missing/broken?"
---

# Scenario Status

Show a single-view dashboard of every scenario's health across the record → review → generate pipeline.

## Phase 0: Load config

Invoke `loading-config` to resolve `<SCENARIO_DIR>` and `<TEST_DIR>`. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair.

## Phase 1: Inventory scenarios

Glob `<SCENARIO_DIR>/**/*.md` (recursive — include drafts). For each file, record:

- **File path** (relative to `<SCENARIO_DIR>`).
- **Is draft?** — lives under a subdirectory (e.g., `drafts/`).
- **Title** — from the `# <Title>` line.
- **URL** — from the `**URL:**` line.
- **Test count** — number of `## Test N:` sections.
- **Has Fixture?** — whether `**Fixture:**` is present.
- **Has Prerequisite?** — whether `**Prerequisite:**` is present.
- **Has extended tags?** — which extended tags are used.

## Phase 2: Check review status

For each non-draft scenario, check `git log -1 --format="%ci" -- <file-path>` to get the last-modified date. This approximates "last reviewed" — scenarios rewritten by `/review-scenario` will show the review date.

If `git` is not available or the file is untracked, report "unknown."

## Phase 3: Check test file status

For each non-draft scenario, derive the expected test file path using the scenario-name → class-name conversion rules from `/scenario-to-tests`:

1. Apply the conversion (strip `.md`, split on separators, title-case, join, prefix `_` if leading digit, append `Test`).
2. Check if `<TEST_DIR>/<ClassName>.kt` (or the appropriate extension for `<TEST_LANGUAGE>`) exists.
3. If the test file exists, check its last-modified date against the scenario's last-modified date. Flag as **stale** if the scenario is newer than the test file.

## Phase 4: Check test results (optional)

Look for the most recent Gradle test report at `build/reports/tests/test/index.html` or `build/test-results/test/*.xml` (JUnit XML format). If found, parse it for pass/fail status of test classes matching `SCENARIOS_PACKAGE.*`.

If no test report is found, skip this phase and report "no test results available — run `/scenario-to-tests` to generate and execute."

## Phase 5: Identify coverage gaps

If a `/crawl-site` inventory exists (look for files in `<SCENARIO_DIR>/drafts/` with the crawl-site provenance blockquote), compare the crawled URLs against the URLs covered by non-draft scenarios. Report:

- **Covered URLs** — URLs that have at least one non-draft scenario.
- **Uncovered URLs** — URLs found by the crawl but not targeted by any scenario.
- **Draft-only URLs** — URLs targeted only by drafts (not yet promoted).

If no crawl inventory exists, skip this section and suggest running `/crawl-site` to establish a baseline.

## Phase 6: Print dashboard

### Scenario health table

```
| Scenario | Status | Tests | Test file | Last reviewed | Test result |
|----------|--------|-------|-----------|---------------|-------------|
| checkout-happy-path | ✓ active | 4 | ✓ current | 2026-04-15 | ✓ pass |
| book-search-filters | ✓ active | 6 | ⚠ stale | 2026-04-14 | ✗ 2 fail |
| intl-shipping-surcharge | draft | 2 | — | — | — |
| nav-to-pricing | draft | 1 | — | — | — |
```

Status values:
- `✓ active` — non-draft scenario, test file exists and is current.
- `⚠ stale` — non-draft scenario, but the test file is older than the scenario (re-run `/scenario-to-tests`).
- `⚠ no tests` — non-draft scenario, but no test file exists.
- `draft` — lives under a subdirectory.

### Summary stats

```
Scenarios: 12 total (8 active, 4 drafts)
Tests: 24 test cases across 8 files (6 passing, 2 failing)
Coverage: 15 of 22 crawled URLs covered (68%)
Stale: 2 scenarios need test regeneration
```

### Recommended actions

Based on the dashboard, suggest the most impactful next steps (up to 5):

1. Fix failing tests: `/scenario-to-tests <name>` for scenarios with test failures.
2. Regenerate stale tests: `/scenario-to-tests <name>` for scenarios newer than their test files.
3. Promote ready drafts: list draft scenarios that look complete.
4. Review uncovered URLs: suggest `/crawl-site` or `/record-scenario` for uncovered pages.
5. Run `/review-scenario` for scenarios not reviewed recently.
