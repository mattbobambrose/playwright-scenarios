---
name: scenario-status
description: Display a health dashboard for all scenarios — last reviewed, test file existence, test pass/fail status, coverage completeness (crawl depth, flow types, conversion rate, critical paths). Use when the user asks "what's the status of my scenarios?" or "what's stale/missing/broken?" or "how much of the site is covered?"
---

# Scenario Status

Show a single-view dashboard of every scenario's health across the record → review → generate pipeline, plus coverage completeness metrics from crawl history.

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
- **Provenance** — parse the blockquote for source (`/crawl-site`, `/record-scenario`, `/doc-to-scenarios`, or hand-written).
- **Flow type** — if the provenance is `/crawl-site`, extract the flow type from the draft filename pattern (nav, hero-cta, footer, auth, content).

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

## Phase 5: Coverage completeness

Analyze coverage across four dimensions. Each dimension is optional — if the required data source doesn't exist, skip that dimension and note what's missing.

### 5a. Crawl depth reached vs. available

Read `<SCENARIO_DIR>/drafts/.crawl-meta.json` if it exists. For each crawl entry:

- Report `max_depth_reached` vs. `max_depth_available`.
- Flag if the crawl was cut short by depth or max-scenarios limits.
- If multiple crawls exist, aggregate: report the deepest crawl and total unique URLs discovered across all crawls.

If `.crawl-meta.json` doesn't exist, skip this section and suggest running `/crawl-site` to establish a baseline.

Dashboard row:
```
Crawl depth: 3 of ~5 levels reached (60%) — 2 crawls, 22 unique URLs discovered
```

### 5b. Flow type coverage

From `.crawl-meta.json`, aggregate flow types across all crawls. Cross-reference with the Phase 1 inventory to determine which flow types have been drafted, promoted to scenarios, and tested:

```
| Flow type  | Discovered | Drafted | Promoted | Tested |
|------------|------------|---------|----------|--------|
| Navigation | 8          | 5       | 3        | 3      |
| Hero CTAs  | 2          | 2       | 1        | 1      |
| Forms      | 4          | 2       | 2        | 0      |
| Auth       | 1          | 0       | 0        | 0      |
| Footer     | 1          | 1       | 0        | 0      |
```

"Discovered" comes from `.crawl-meta.json`. "Drafted" = draft scenarios with matching flow type. "Promoted" = non-draft scenarios with matching URLs. "Tested" = promoted scenarios that have test files.

If `.crawl-meta.json` doesn't exist, skip this table.

### 5c. Scenario-to-test conversion rate

Consolidate the Phase 1 + Phase 3 data into a clear metric:

```
Conversion: 8 of 12 scenarios have generated tests (67%)
  - 8 active with tests
  - 2 active without tests (run /scenario-to-tests)
  - 4 drafts (promote first)
```

This section always runs — it doesn't depend on crawl metadata.

### 5d. Critical path coverage

Read `<SCENARIO_DIR>/.critical-paths.md` if it exists. This file lists the user's critical user journeys as chains of scenario names:

```markdown
# Critical Paths

- checkout-happy-path → payment-flow → order-confirmation
- signup → first-purchase
- search → product-detail → add-to-cart
```

For each path, check whether every scenario in the chain:
1. Exists (as a non-draft scenario file).
2. Has been reviewed (last-modified date is recent enough or has a test file).
3. Has a generated test file.
4. Has passing tests (if test results are available from Phase 4).

Report:

```
Critical paths: 2 of 3 fully covered
  ✓ checkout → payment → confirmation (all tested, all passing)
  ✓ signup → first-purchase (all tested, all passing)
  ✗ search → product → cart (search-for-book: no tests)
```

If `.critical-paths.md` doesn't exist, skip this section and suggest creating one:

> No critical paths defined. Create `<SCENARIO_DIR>/.critical-paths.md` listing your most important user journeys to track their coverage. Example:
> ```
> - checkout-happy-path → payment-flow → order-confirmation
> ```

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
Crawl depth: 3 of ~5 levels (60%)
Flow types: 3 of 5 types have scenarios
Conversion: 8 of 12 scenarios have tests (67%)
Critical paths: 2 of 3 fully covered
Stale: 2 scenarios need test regeneration
```

Lines for dimensions with no data source (no `.crawl-meta.json`, no `.critical-paths.md`, no test results) are omitted, not shown as zeroes.

### Recommended actions

Based on the dashboard, suggest the most impactful next steps (up to 7, ordered by impact):

1. Fix failing tests: `/scenario-to-tests <name>` for scenarios with test failures.
2. Regenerate stale tests: `/scenario-to-tests <name>` for scenarios newer than their test files.
3. Generate tests for untested scenarios: `/scenario-to-tests <name>`.
4. Promote ready drafts: list draft scenarios that look complete.
5. Cover missing flow types: suggest `/crawl-site` with a description targeting the uncovered type (e.g., "focus on auth flows").
6. Deepen the crawl: if `max_depth_reached < max_depth_available`, suggest `/crawl-site <url> deep dive --depth=<available>`.
7. Define critical paths: if `.critical-paths.md` doesn't exist, suggest creating it.
