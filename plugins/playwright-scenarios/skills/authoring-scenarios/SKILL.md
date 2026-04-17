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
- **`**Fixture:** <path>`** — References a typed fixture file (e.g. `fixtures/returning-customer`). The test generator imports it rather than inlining data values. Place at the top of the scenario alongside `**URL:**`.
- **`**Prerequisite:** <scenario-name> (Tests N-M)`** — Declares that this scenario depends on another scenario's flow as setup. The test generator emits a `beforeAll` (or setup test block) that runs the referenced scenario's flow, sharing the page across tests. Place at the top of the scenario.
- **`**Assert throughout:** <assertion>`** — A flow-wide assertion checked across the entire test, not scoped to a single test case (e.g. "No application JS console errors"). The test generator wraps the flow in a listener and asserts at the end. Place at the top of the scenario.
- **`**Expected failure:** <reason>`** — Marks a test as expected to fail today. Place as the first bullet inside a `## Test N:` section, before any Action/Expected bullets. The test generator emits `test.fail()` (Playwright TS) or the framework's equivalent. When the underlying bug is fixed, the test flips from "expected failure" to real failure, signaling the guard can be removed.
- **`**Expected (regex):** <pattern>`** — Like `**Expected:**` but uses regex matching instead of exact substring. The test generator emits `toMatch(/<pattern>/i)` instead of `shouldContain`. Use for assertions where the content varies between runs (e.g. LLM-generated text) but should match a semantic pattern.
- **`**Iframe:** <selector>`** — Declares that all actions and assertions in this scenario (or from this point forward) target content inside the specified iframe. The test generator wraps subsequent locators in `page.frameLocator('<selector>')` instead of using `page` directly. Place at the top of the scenario alongside `**URL:**` if the entire flow is inside one iframe, or inline before the first action that enters the iframe. Use CSS selectors (`#stripe-payment-iframe`), `name` attributes (`[name="checkout"]`), or `src` patterns (`iframe[src*="stripe.com"]`). If the flow exits the iframe (e.g., a confirmation page outside the payment form), add `**Iframe:** none` at the point where actions return to the top-level page.
- **`**Branch:** <fixture-field> = <value>`** — Declares that this scenario tests an alternate path by overriding one field in the base fixture. Requires a `**Fixture:**` tag on the same scenario. The test generator loads the referenced fixture, overrides the named field, and runs the flow with the modified data. Write one scenario per branch. Example: `**Branch:** shipping.country = CA` tests the international shipping surcharge using the same customer but with country overridden to Canada. Place at the top of the scenario alongside `**Fixture:**`.
- **`**Intercept:** <url-pattern> → <status> [body]`** — Mock a network request during the test. The test generator emits a `page.route()` call that intercepts matching URLs and returns the specified status code and optional JSON body. Use for testing error states, empty states, and degraded-service behavior that can't be triggered via the UI. Place before the Action that triggers the request. Examples: `**Intercept:** **/api/checkout → 500` (test API failure), `**Intercept:** **/api/recommendations → 200 {"items": []}` (test empty-state rendering).
- **`**Cookie:** <name>=<value> [domain=<d>] [httpOnly] [secure]`** — Set a cookie before the flow starts. The test generator emits a `context.addCookies()` call before the first navigation. Use for: pre-authenticated state, feature flags, A/B test buckets, locale preferences, "returning user" behavior. Place at the top of the scenario alongside `**URL:**`.
- **`**Storage:** <key>=<value>`** — Set a localStorage or sessionStorage entry before the flow starts. The test generator emits `page.evaluate(() => localStorage.setItem('<key>', '<value>'))` after the first navigation. Use for: client-side feature flags, theme preferences, onboarding-dismissed state, cached user data. Place at the top of the scenario alongside `**URL:**`.
- **`**Device:** <preset>`** — Emulate a device using Playwright's built-in device descriptors (e.g., `iPhone 14`, `Pixel 7`, `iPad Pro 11`). Sets viewport dimensions and user-agent string. The test generator emits `browser.newContext({ ...devices['<preset>'] })`. More expressive than `**Viewport:**` alone — captures user-agent spoofing for responsive sites that detect mobile via UA string. Place at the top of the scenario alongside `**URL:**`.
- **`**Timeout:** <ms>`** — Override the default per-test timeout for this scenario or test. Place at the top of the scenario (applies to all tests) or inside a specific `## Test N:` section (applies to that test only). The test generator emits `test.setTimeout(<ms>)` or the framework equivalent. Use sparingly — prefer fixing race conditions over extending timeouts.
- **`**Cleanup:** <action>`** — A teardown action executed after the test completes (pass or fail). The test generator emits the action inside an `afterEach` or `afterAll` block. Use for: deleting accounts created during the test, clearing carts, resetting state. Place at the top of the scenario (runs after all tests) or inside a specific `## Test N:` section. Actions follow the same imperative voice as `**Action:**` bullets.

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
# Order Confirmation

**URL:** https://bookstore.example.com/order/confirm
**Fixture:** fixtures/returning-customer
**Prerequisite:** checkout-happy-path (Tests 1-3)

Verify the order confirmation page renders correctly after completing checkout.

## Test 1: Header shows customer name

- **Expected:** A heading containing "Thank you, Alex!" is present

## Test 2: Recommendation is personalized

- **Action:** Locate the "You might also like" section
- **Expected (regex):** The text matches /fiction|mystery|thriller/i

## Test 3: Duplicate order error grammar

- **Expected failure:** Copy bug — "has" missing from error message
- **Action:** Submit the same order again
- **Expected:** Error reads "This order has already been placed."
```

### Iframe boundary

```markdown
# Checkout Happy Path

**URL:** https://bookstore.example.com/checkout
**Iframe:** #stripe-payment-iframe
**Fixture:** fixtures/returning-customer

The payment form is hosted inside a cross-origin Stripe iframe.

## Test 1: Enter card details

- **Action:** Enter '4242424242424242' into the 'Card number' field.
- **Action:** Enter '12/28' into the 'Expiry' field.
- **Action:** Click the 'Pay now' button.
- **Expected:** The heading 'Order confirmed' is visible.

## Test 3: Enter shipping address (outside iframe)

**Iframe:** none

- **Action:** Enter '123 Main St' into the 'Address' field.
- **Action:** Click the 'Save Address' button.
- **Expected:** The URL changes to `/checkout/review`.
```

### Branch (alternate path)

```markdown
# International Shipping Surcharge

**URL:** https://bookstore.example.com/checkout
**Iframe:** #stripe-payment-iframe
**Fixture:** fixtures/returning-customer
**Branch:** shipping.country = CA

Test the international shipping surcharge using the standard customer with country overridden.

## Test 1: Surcharge applied for non-US address

- **Action:** Select 'Canada' from the 'Country' dropdown.
- **Action:** Click the 'Calculate Shipping' button.
- **Expected:** The text 'International shipping surcharge: $12.99' is visible.
- **Expected:** The order total updates to reflect the surcharge.
```

## After editing

If you made non-trivial changes to a scenario (not just a typo), suggest the user run `/review-scenario <name>` to re-validate claims against the live site before regenerating tests with `/scenario-to-tests`.
