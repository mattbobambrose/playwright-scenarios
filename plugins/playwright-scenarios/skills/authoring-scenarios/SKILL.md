---
name: authoring-scenarios
description: Conventions for hand-writing or editing scenario markdown files in the project's scenario directory — the flat format that /review-scenario audits and /scenario-to-tests consumes. Use when creating or modifying any scenario markdown file directly (not via /record-scenario), or when the user asks about the scenario format. The scenario directory is configured in .claude/playwright-scenarios.local.md (default: src/test/scenarios/).
---

# Authoring Scenarios

Scenarios are flat markdown files in the project's configured scenario directory (`scenario_dir` in `.claude/playwright-scenarios.local.md`; default `src/test/scenarios/`). They describe a browser flow in human-readable Action/Expected pairs. They are authored three ways:

1. **Recorded** via `/record-scenario` (Playwright codegen).
2. **Hand-written** by the user or Claude (this skill).
3. **Audited and rewritten in place** by `/review-scenario`.

All three produce files that must conform to the format below, because `/scenario-to-tests` translates them into test code in the language and framework configured in `.claude/playwright-scenarios.local.md` (defaults: Kotlin + Kotest StringSpec, using Playwright-for-Java).

## File structure

```markdown
# <Title Case Title>

**URL:** <start path or full url>

<Optional one-line description of the flow.>

## Test 1: <short imperative description>

- **Action:** <what the user does>
- **Expected:** <what should be true after the action>

## Test 2: <short imperative description>

- **Action:** ...
- **Expected:** ...
```

### Required elements

- **Top-level `# <Title>`** — Title Case, derived from the kebab-case filename.
- **`**URL:**` line** — the starting URL. Relative paths (e.g. `/web/home`) are resolved against the project's configured base URL; full URLs (`https://...`) are used as-is.
- **One or more `## Test N:` sections** — numbered sequentially from 1. Each generates one `@Test`-style Kotest block.
- **At least one `- **Action:**` and one `- **Expected:**` bullet per test.**

### Optional elements

- **`**Viewport:** <w>x<h>`** as a top-level bullet sets the browser viewport (e.g. `**Viewport:** 390x844` for mobile).
- **Input data bullets** like `- **Email:** foo@bar.com` or `- **Password:** hunter2` — these are referenced by a later `- **Action:** Enter email ...` bullet and get inlined into the generated test.
- **`**Fixture:** <path>`** — References a typed fixture file (e.g. `fixtures/sarah-mitchell`). The test generator imports it rather than inlining data values. Place at the top of the scenario alongside `**URL:**`.
- **`**Prerequisite:** <scenario-name> (Tests N-M)`** — Declares that this scenario depends on another scenario's flow as setup. The test generator emits a `beforeAll` (or setup test block) that runs the referenced scenario's flow, sharing the page across tests. Place at the top of the scenario.
- **`**Assert throughout:** <assertion>`** — A flow-wide assertion checked across the entire test, not scoped to a single test case (e.g. "No application JS console errors"). The test generator wraps the flow in a listener and asserts at the end. Place at the top of the scenario.
- **`**Expected failure:** <reason>`** — Marks a test as expected to fail today. Place as the first bullet inside a `## Test N:` section, before any Action/Expected bullets. The test generator emits `test.fail()` (Playwright TS) or the framework's equivalent. When the underlying bug is fixed, the test flips from "expected failure" to real failure, signaling the guard can be removed.
- **`**Expected (regex):** <pattern>`** — Like `**Expected:**` but uses regex matching instead of exact substring. The test generator emits `toMatch(/<pattern>/i)` instead of `shouldContain`. Use for assertions where the content varies between runs (e.g. LLM-generated text) but should match a semantic pattern.

## Authoring rules

### Voice
- **Action:** imperative voice — "Click 'Log In'", "Enter the email", "Scroll to the footer".
- **Expected:** descriptive voice — "The login form is replaced by the dashboard", "A red 'Required' error appears under the email field".

### Selectors
Preserve concrete text that `/review-scenario` can match against the live DOM:
- Role + name: "Click the **'Log In'** link" (maps to `getByRole(LINK, setName("Log In"))`).
- Labels: "Enter **'foo@bar.com'** into the **Email** field" (maps to `getByLabel("Email")`).
- Visible text: "The banner showing **'Thank you!'** is visible" (maps to `getByText("Thank you!")`).

Avoid abstract descriptions like "the submit button" when a role+name exists. `/review-scenario` will replace vague selectors with concrete ones when it audits; `/scenario-to-tests` fails gracefully on vague selectors but produces flakier tests.

### Test grouping
- One continuous flow → one `## Test 1:` section.
- Same form exercised with multiple inputs → one `## Test N:` per input set, each with its own data bullets.
- Re-navigation back to the start URL usually marks a new Test.

### Known gotchas

- **Native HTML5 validation tooltips** are not DOM elements. For a "required field" assertion, write `- **Expected:** The email field reports a missing-value validation error` — `/scenario-to-tests` translates this to `validity.valueMissing` / `validity.typeMismatch` checks, not text assertions.
- **Links that open in a new tab** (e.g. `target="_blank"` to another origin) should be expressed as `- **Expected:** The '<label>' link points to <url>` — the generated test checks `getAttribute("href")` rather than clicking, which avoids cross-origin test pollution.

## Examples

### Basic scenario

```markdown
# Email Signup Form

**URL:** /web/home

A visitor subscribes to the newsletter from the homepage footer.

## Test 1: Submit with a valid email

- **Email:** subscriber@example.com
- **Action:** Scroll to the footer.
- **Action:** Enter the email into the 'Email address' field.
- **Action:** Click the 'Subscribe' button.
- **Expected:** The form is replaced by a 'Thanks for subscribing!' confirmation.

## Test 2: Submit with an invalid email

- **Email:** not-an-email
- **Action:** Scroll to the footer.
- **Action:** Enter the email into the 'Email address' field.
- **Action:** Click the 'Subscribe' button.
- **Expected:** The email field reports a type-mismatch validation error.
```

### Extended tags

```markdown
# Care Plan Structure

**URL:** https://app.eo.care/careplan
**Fixture:** fixtures/sarah-mitchell
**Prerequisite:** profiling-happy-path (Tests 1-4)

Verify the rendered care plan structure after completing the profiling flow.

## Test 1: Header renders with patient name

- **Expected:** A heading containing "Sarah's Care Plan" is present

## Test 2: Recommendation is personalized

- **Action:** Locate the "Why this?" recommendation text
- **Expected (regex):** The text matches /chemotherapy|cancer|carcinoma/i

## Test 3: Email collision error grammar

- **Expected failure:** Copy bug — "is" missing from error message
- **Action:** Submit with duplicate email
- **Expected:** Error reads "The email address is already taken."
```

## After editing

If you made non-trivial changes to a scenario (not just a typo), suggest the user run `/review-scenario <name>` to re-validate claims against the live site before regenerating tests with `/scenario-to-tests`.
