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

## Example

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

## After editing

If you made non-trivial changes to a scenario (not just a typo), suggest the user run `/review-scenario <name>` to re-validate claims against the live site before regenerating tests with `/scenario-to-tests`.
