# playwright-scenarios — Usage Guide

LLM-optimized reference for using the `playwright-scenarios` plugin in a host project. Add this to your project's CLAUDE.md or pass it as context when working with scenarios.

---

## Terminology

**Input** (what enters the plugin)
- **Doc** — any document describing what to test: requirements doc, test plan, meeting notes, acceptance criteria, Jira tickets. Not in scenario format yet. Input to `evaluate-doc` and `/doc-to-scenarios`. One doc typically contains multiple user flows, each of which becomes one scenario.

**Plugin artifacts** (what the plugin works with)
- **Scenario** — a flat markdown file (`# Title`, `**URL:**`, `## Test N:` blocks with Action/Expected pairs). The central artifact.
- **Test case** — a single `## Test N:` section inside a scenario. Each becomes one test function.
- **Source partition** — the subdirectory under `<scenario_dir>` that records which command produced the scenario: `<scenario_dir>/record/`, `<scenario_dir>/crawl/`, `<scenario_dir>/convert/`. Generated tests mirror the partition under `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`.
- **Fixture** — a JSON file (`<scenario_dir>/fixtures/<name>.json`) with structured test data. Referenced via `**Fixture:** fixtures/<name>`.
- **Tag** — a bold-label directive (`**Iframe:**`, `**Intercept:**`, etc.) that controls test generation beyond Action/Expected.

**Output** (what the plugin produces)
- **Generated test** — a Kotlin/TypeScript/Python test file. One file per scenario, one test function per test case.

## Commands — when to use which

| If you want to... | Use | Notes |
|---|---|---|
| Record a user flow by driving a browser | `/record-scenario [url] [name]` | Opens Playwright codegen. Writes to `<scenario_dir>/record/<name>.md`. Pass a URL to skip the Start URL prompt. |
| Auto-discover flows on a site | `/crawl-site <start-url> [description] [--depth=N] [--max-scenarios=N]` | Read-only. Accepts natural-language scope ("focus on checkout"). A bare URL crawls with defaults (depth 1, max 10 scenarios). Writes to `<scenario_dir>/crawl/`. |
| Check if a doc is testable | `evaluate-doc` (skill — invoke by asking Claude to evaluate the doc, no slash command) | Advisory. Reports what converts, what needs changes, what's out of scope. |
| Convert a doc into scenarios | `/doc-to-scenarios <path> [--skip-evaluation]` | Runs evaluate-doc first. Writes to `<scenario_dir>/convert/`. |
| Create a fixture file | `/generate-fixture <source \| interactive> [--name=N]` | From a scenario, document, or interactive prompts. |
| Audit scenarios against the live site | `/review-scenario [names...]` | Reviews across `record/`, `crawl/`, `convert/`. Pass a partition name to scope. Verifies claims, tightens assertions, adds coverage. |
| Generate test code | `/scenario-to-tests [names...] [--dry-run]` | Output at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`. Pass a partition name to scope. Currently: Kotlin + Kotest only. |
| Check scenario health | `/scenario-status [description]` | Dashboard grouped by partition: review dates, test staleness, pass/fail, crawl depth, flow type coverage, conversion rate, critical paths. Optional natural-language description ("focus on what's broken", "executive summary") biases what's emphasized. |
| View or change config | `/playwright-scenarios-config` | Also the recovery path for malformed config. |
| Generate a `BasePageTest` to extend | `/scaffold-base-test` | One-shot setup. Prompts for `/reset` endpoint, lifecycle scope, browser. Writes `BasePageTest.kt` at the parent of `<test_dir>` and persists `base_test_class`. Currently: Kotlin + Kotest only. Also auto-offered by `loading-config` when no base class is found. |

## Workflow

```
Document ──→ /evaluate-doc ──→ /doc-to-scenarios ──→ <scenario_dir>/convert/
                                                                          │
Browser recording ──→ /record-scenario ────────────→ <scenario_dir>/record/
                                                                          │
Site crawl ──→ /crawl-site ────────────────────────→ <scenario_dir>/crawl/
                                                                          │
                          (optional) hand-edit / delete scenarios in place ┤
                                                                          │
                                                          /review-scenario │
                                                                          │
                                                       /scenario-to-tests ──→ <test_dir>/<command>/<scenario-name>/<ClassName>.kt
```

**Decision tree:**
- Have a written document? → `/doc-to-scenarios` (writes to `convert/`)
- Know the flow but no document? → `/record-scenario` (writes to `record/`)
- Don't know what flows exist? → `/crawl-site` (writes to `crawl/`)
- Have scenarios, want to verify them? → `/review-scenario`
- Have reviewed scenarios, want tests? → `/scenario-to-tests`

## Scenario format — quick reference

```markdown
# Title Case Title

**URL:** /start-path
**Fixture:** fixtures/persona-name
**Iframe:** #iframe-selector
**Device:** iPhone 14

Optional one-line description.

> Provenance: Recorded/Converted/Crawled by <command>.

## Test 1: Short imperative description

- **Action:** Click the 'Submit' button.
- **Expected:** The heading 'Thank you' is visible.
- **Expected:** The URL changes to /confirmation.
```

**Required per scenario:** `# Title`, `**URL:**`, at least one `## Test N:`.
**Required per test case:** at least one `**Action:**` and one `**Expected:**`.

## Tag reference

### Scenario-level tags (place at top alongside `**URL:**`)

| Tag | Purpose | Example |
|-----|---------|---------|
| `**Fixture:** <path>` | Load typed test data | `**Fixture:** fixtures/returning-customer` |
| `**Branch:** <field> = <value>` | Override one fixture field for alternate path | `**Branch:** basics.age = 18` |
| `**Prerequisite:** <name> (Tests N-M)` | Run another scenario as setup | `**Prerequisite:** login-flow (Tests 1-3)` |
| `**Assert throughout:** <assertion>` | Flow-wide invariant | `**Assert throughout:** No JS console errors` |
| `**Iframe:** <selector>` | Target iframe content | `**Iframe:** #stripe-payment-iframe` |
| `**Iframe:** none` | Return to top-level page | (place inline where flow exits iframe) |
| `**Cookie:** <name>=<value>` | Pre-set a cookie | `**Cookie:** auth_token=abc123` |
| `**Storage:** <key>=<value>` | Pre-set localStorage | `**Storage:** feature_flag=dark_mode_v2` |
| `**Device:** <preset>` | Emulate device (viewport + UA) | `**Device:** Pixel 7` |
| `**Viewport:** <w>x<h>` | Set viewport only (no UA) | `**Viewport:** 390x844` |
| `**Timeout:** <ms>` | Override timeout (all tests) | `**Timeout:** 60000` |
| `**Cleanup:** <action>` | Teardown after all tests | `**Cleanup:** Delete the test account` |

### Test-case-level tags (place inside `## Test N:`)

| Tag | Purpose | Example |
|-----|---------|---------|
| `**Expected failure:** <reason>` | Known bug — flips when fixed | `**Expected failure:** Missing "is" in error copy` |
| `**Expected (regex):** <pattern>` | Regex match for variable content | `**Expected (regex):** /fiction\|mystery\|thriller/i` |
| `**Intercept:** <pattern> → <status> [body]` | Mock a network request | `**Intercept:** **/api/plan → 500` |
| `**Timeout:** <ms>` | Override timeout (this test only) | `**Timeout:** 90000` |
| `**Cleanup:** <action>` | Teardown after this test | `**Cleanup:** Clear the shopping cart` |

### Data bullets (place inside `## Test N:`, before Action)

| Pattern | Purpose | Example |
|---------|---------|---------|
| `**<Label>:** <value>` | Input data for a form field | `**Email:** test@example.com` |

## Writing rules

**Action bullets** — imperative voice: "Click 'Log In'", "Enter the email", "Scroll to the footer."
**Expected bullets** — descriptive voice: "The heading 'Dashboard' is visible", "A red error appears."
**Selectors** — use exact DOM text: "Click the **'Subscribe'** button" (not "click the submit button"). Include `data-*` attributes when available: "Click the 'Science Fiction' checkbox (`data-category=\"sci-fi\"`)."

## Do

- Always run `/review-scenario` before `/scenario-to-tests` — it grounds claims against the live site.
- Use one scenario per user flow. Use multiple test cases within a scenario for related assertions on the same flow.
- Use `**Fixture:**` for reusable test data instead of repeating inline data bullets across scenarios.
- Use `**Branch:**` + `**Fixture:**` for alternate paths (one scenario per branch, same base fixture).
- Use `**Expected failure:**` for known bugs — they become regression guards.
- Use `**Expected (regex):**` for LLM-generated or variable content.
- Use `**Iframe:**` whenever a flow enters a cross-origin iframe. Use `**Iframe:** none` when it exits.
- Use `**Intercept:**` for error states that can't be triggered via the UI.
- Note iframe boundaries prominently — a missing `**Iframe:**` tag causes every selector to fail silently.
- Use concrete selector text (exact link text, labels, headings) — vague selectors produce flaky tests.

## Don't

- Don't write scenarios for things the plugin can't test: cross-run comparison, visual regression, accessibility, performance, network-layer testing, or stateful branching logic (use one scenario per branch instead).
- Don't assume behaviors — verify against the live site via `/review-scenario`. Documents written from memory often contain claims that don't match reality.
- Don't use display text as data values — use DOM identifiers (`data-category="sci-fi"`, not "Science Fiction & Fantasy").
- Don't mix test definitions with implementation recommendations in documents — the plugin handles implementation decisions via its config.
- Don't skip `**Iframe:**` for cross-origin iframes — this is the #1 cause of "all tests fail with element not found."
- Don't use raw "test" without qualification — say "test case" (a `## Test N:` section), "test file" (the generated code), or "test run" (executing the tests).
- Don't put production secrets in fixtures — use test-only credentials and flag them clearly.
- Don't rely on `**Timeout:**` to fix race conditions — prefer adding an Expected assertion that waits for readiness (e.g., "The spinner is not visible").

## When tests fail

Check in this order (stop at first match):

1. **Iframe not declared?** Every selector fails → add `**Iframe:** <selector>`.
2. **Selector drift?** Some selectors fail → element text changed on the live site → update scenario, re-run `/review-scenario`.
3. **Timing?** Tests pass inconsistently → add an Expected assertion before the flaky Action, or add `**Timeout:**` as a last resort.
4. **Cross-origin boundary?** Tests fail after navigation → add `**Iframe:** none` at the transition point.
5. **Stale fixture?** Form rejects data → email already taken, wrong format → update fixture values.
6. **Wrong code structure?** Compile errors → check `test_dir`, `source_root`, `base_test_class` via `/playwright-scenarios-config`.

## Config quick reference

Stored in `.claude/playwright-scenarios.local.md`. Created on first command run.

| Field | Required | Default | Purpose |
|-------|----------|---------|---------|
| `scenario_dir` | yes | `src/test/scenarios` | Scenario markdown location |
| `test_dir` | yes | language-aware (e.g., `tests/scenarios` for Python/TS, `src/test/kotlin/.../scenarios` for Kotlin) | Generated test file location |
| `test_language` | yes | `kotlin` | Target language |
| `test_framework` | yes | `kotest-stringspec` | Target framework |
| `source_root` | no | inferred | Source-set root for package derivation |
| `base_test_class` | no | auto-detected or scaffolded | Base class for generated tests. If none exists, `loading-config` offers to scaffold one via `/scaffold-base-test`. |
