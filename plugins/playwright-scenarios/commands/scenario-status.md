---
name: scenario-status
description: Display a health dashboard for all scenarios across crawl/record/convert folders — last reviewed, test file existence, test pass/fail status, coverage completeness (crawl depth, flow types, conversion rate, critical paths). Accepts an optional natural-language description that biases the report ("focus on what's broken", "give me a one-paragraph executive summary", "what should I work on this week?", "only the checkout-related scenarios"). Use when the user asks "what's the status of my scenarios?" or "what's stale/missing/broken?" or "how much of the site is covered?" or asks for a tailored summary.
summary: 'Health dashboard grouped by folder: review dates, test status, pass/fail, plus coverage completeness (crawl depth, flow types, conversion rate, critical paths). Accepts a natural-language description ("focus on what''s broken") to bias the rendering.'
signature: /scenario-status [description]
arguments:
  - name: description
    description: Optional. A natural-language description of what to focus on in the report (e.g. "focus on what's broken", "executive summary", "only the checkout-related scenarios"). Biases what Phase 6 emphasizes, condenses, or skips. Without it, the full default dashboard is rendered.
    required: false
---

# Scenario Status

Show a single-view dashboard of every scenario's health across the crawl / record / convert folders, plus coverage completeness metrics from crawl history.

## Argument parsing

Everything after the command name, joined into one string, is the optional **focus description** (`<FOCUS>`). It's free-form English describing what the user wants emphasized.

**Examples:**

```
/scenario-status
/scenario-status focus on what's broken
/scenario-status give me a one-paragraph executive summary
/scenario-status what should I work on this week?
/scenario-status only the checkout-related scenarios
```

If `<FOCUS>` is empty, render the default full dashboard (Phase 6 as written). If `<FOCUS>` is provided, Phases 1–5 still gather the full picture (data collection is cheap and the description should not silently change what's "true" about the report); Phase 6 then uses `<FOCUS>` to shape what's expanded, condensed, or skipped, and may lead with a tailored prose summary.

## Phase 0: Load config

Invoke `loading-config` to resolve `<SCENARIO_DIR>` and `<TEST_DIR>`. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair.

## Phase 1: Inventory scenarios

Glob `<SCENARIO_DIR>/{crawl,record,convert}/*.md`. Skip any `SCENARIOS.md` and `.crawl-meta.json`. For each file, record:

- **Folder** — `crawl`, `record`, or `convert`, derived from the parent directory.
- **File path** (relative to `<SCENARIO_DIR>`).
- **Scenario name** (filename without `.md`).
- **Title** — from the `# <Title>` line.
- **URL** — from the `**URL:**` line.
- **Test count** — number of `## Test N:` sections.
- **Has Fixture?** — whether `**Fixture:**` is present.
- **Has Prerequisite?** — whether `**Prerequisite:**` is present.
- **Has extended tags?** — which extended tags are used.
- **Provenance** — parse the blockquote for source (`/crawl-site`, `/record-scenario`, `/doc-to-scenarios`, or hand-written).
- **Flow type** — if the folder is `crawl`, extract the flow type from the filename pattern (nav, hero-cta, footer, auth, content) when available.

## Phase 2: Check review status

For each scenario, check `git log -1 --format="%ci" -- <file-path>` to get the last-modified date. This approximates "last reviewed" — scenarios rewritten by `/review-scenario` will show the review date.

If `git` is not available or the file is untracked, report "unknown."

## Phase 3: Check test file status

For each scenario, derive the expected test file path:

1. Apply the scenario-name → class-name conversion rules from `/scenario-to-tests` (strip `.md`, split on separators, title-case, join, prefix `_` if leading digit, append `Test`).
2. Check if `<TEST_DIR>/<command>/<scenario-name>/<ClassName>.kt` exists.
3. If the test file exists, check its last-modified date against the scenario's last-modified date. Flag as **stale** if the scenario is newer than the test file.

## Phase 4: Check test results (optional)

Look for the most recent Gradle test report at `build/reports/tests/test/index.html` or `build/test-results/test/*.xml` (JUnit XML format). If found, parse it for pass/fail status of test classes matching `<SCENARIOS_PACKAGE>.{crawl,record,convert}.*`.

If no test report is found, skip this phase and report "no test results available — run `/scenario-to-tests` to generate and execute."

## Phase 5: Coverage completeness

Analyze coverage across four dimensions. Each dimension is optional — if the required data source doesn't exist, skip that dimension and note what's missing.

### 5a. Crawl depth reached vs. available

Read `<SCENARIO_DIR>/crawl/.crawl-meta.json` if it exists. For each crawl entry:

- Report `max_depth_reached` vs. `max_depth_available`.
- Flag if the crawl was cut short by depth or max-scenarios limits.
- If multiple crawls exist, aggregate: report the deepest crawl and total unique URLs discovered across all crawls.

If `.crawl-meta.json` doesn't exist, skip this section and suggest running `/crawl-site` to establish a baseline.

Dashboard row:
```
Crawl depth: 3 of ~5 levels reached (60%) — 2 crawls, 22 unique URLs discovered
```

### 5b. Flow type coverage

From `.crawl-meta.json`, aggregate flow types across all crawls. Cross-reference with the Phase 1 inventory to determine which flow types have been emitted (live in `<SCENARIO_DIR>/crawl/`) and tested:

```
| Flow type  | Discovered | In `crawl/` | Tested |
|------------|------------|-------------|--------|
| Navigation | 8          | 5           | 3      |
| Hero CTAs  | 2          | 2           | 1      |
| Forms      | 4          | 2           | 0      |
| Auth       | 1          | 0           | 0      |
| Footer     | 1          | 1           | 0      |
```

"Discovered" comes from `.crawl-meta.json`. "In `crawl/`" = crawl-folder scenarios with matching flow type (some may have been deleted by the user). "Tested" = scenarios that have test files.

If `.crawl-meta.json` doesn't exist, skip this table.

### 5c. Scenario-to-test conversion rate

Consolidate the Phase 1 + Phase 3 data into a clear metric, broken down by folder:

```
Conversion: 8 of 12 scenarios have generated tests (67%)
  - record: 3 of 4 (run /scenario-to-tests record to fill the gap)
  - crawl: 4 of 6 (run /scenario-to-tests crawl)
  - convert: 1 of 2 (run /scenario-to-tests convert)
```

This section always runs — it doesn't depend on crawl metadata.

### 5d. Critical path coverage

Read `<SCENARIO_DIR>/.critical-paths.md` if it exists. This file lists the user's critical user journeys as chains of scenario names (which may live in any folder):

```markdown
# Critical Paths

- checkout-happy-path → payment-flow → order-confirmation
- signup → first-purchase
- search → product-detail → add-to-cart
```

For each path, check whether every scenario in the chain:
1. Exists (in any folder under `<SCENARIO_DIR>/{crawl,record,convert}/`).
2. Has been reviewed recently (last-modified date) or has a test file.
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

### Output invariants (apply in all modes)

Regardless of `<FOCUS>` or formatting choice, every reference to a scenario in the report must make its **source folder** (`crawl`, `record`, or `convert`) visible to the user. This rule applies to:

- The per-folder tables — render the `=== crawl ===` / `=== record ===` / `=== convert ===` headers even when one folder is empty (write `(no scenarios)` underneath rather than dropping the section).
- The leading prose summary (when `<FOCUS>` is set) — name folders when citing counts, e.g. "3 stale scenarios, all in `crawl/`" rather than "3 stale scenarios."
- Any per-scenario callout in **Recommended actions** — qualify the scenario name with its folder, e.g. `record/checkout-happy-path` or "the crawl scenario `nav-to-pricing`."
- Filtered views — keep folder headers (or folder badges per row) so a filtered list still tells the user which command produced each scenario.

The user must never have to cross-reference a scenario name back to its source command; the report always answers that question itself.

### If `<FOCUS>` was provided

Interpret the description against the data gathered in Phases 1–5 and decide:

1. **Lead with a prose summary** that directly answers the user's question. 1–3 short paragraphs, citing concrete numbers from the gathered data. Place this *before* any tables.
2. **Pick which standard sections to keep, condense, or skip:**
   - Sections that bear on the focus → keep in full.
   - Sections that are tangential → condense to a single line, or drop.
   - Sections with no data (no `.crawl-meta.json`, no `.critical-paths.md`, no test report) → still drop, as today.
3. **Reorder / filter the Recommended actions** so the top items match the focus. Cap at 7. Drop suggestions that don't relate.
4. **If the focus implies a filter** (e.g. "only the checkout-related scenarios", "stale ones only"), apply it to the per-folder tables — don't show rows that don't match. Note the filter in the section header (e.g. `=== record (filtered: checkout-related) ===`).

After the prose summary, render the kept sections in the same order as the default dashboard below. Don't invent new section types — re-arrange and re-emphasize the existing ones.

### Scenario health table — grouped by folder

```
=== crawl ===
| Scenario | Status | Tests | Test file | Last reviewed | Test result |
|----------|--------|-------|-----------|---------------|-------------|
| nav-to-pricing | ⚠ no tests | 1 | — | 2026-04-20 | — |

=== record ===
| Scenario | Status | Tests | Test file | Last reviewed | Test result |
|----------|--------|-------|-----------|---------------|-------------|
| checkout-happy-path | ✓ active | 4 | ✓ current | 2026-04-15 | ✓ pass |
| book-search-filters | ✓ active | 6 | ⚠ stale | 2026-04-14 | ✗ 2 fail |

=== convert ===
| Scenario | Status | Tests | Test file | Last reviewed | Test result |
|----------|--------|-------|-----------|---------------|-------------|
| intl-shipping-surcharge | ⚠ no tests | 2 | — | 2026-04-20 | — |
```

Status values:
- `✓ active` — test file exists and is current.
- `⚠ stale` — test file is older than the scenario (re-run `/scenario-to-tests`).
- `⚠ no tests` — no test file exists yet.

### Summary stats

```
Scenarios: 12 total (6 crawl, 4 record, 2 convert)
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
3. Generate tests for untested scenarios: `/scenario-to-tests <command>` to cover a whole folder, or `/scenario-to-tests <name>` for a single scenario.
4. Cover missing flow types: suggest `/crawl-site` with a description targeting the uncovered type (e.g., "focus on auth flows").
5. Deepen the crawl: if `max_depth_reached < max_depth_available`, suggest `/crawl-site <start-url> deep dive --depth=<available>`.
6. Define critical paths: if `.critical-paths.md` doesn't exist, suggest creating it.
