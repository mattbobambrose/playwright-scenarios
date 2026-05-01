# Writing Testable Documents

Rules for writing documents that can be converted into automated Playwright tests. Paste this into your LLM's system prompt, custom instructions, or at the start of a conversation when generating test documents.

---

## What the test framework can handle

The test generator translates human-readable documents into Playwright browser automation. It supports:

| Capability | How to express it in your document |
|------------|-------------------------------|
| Multi-page flows | Numbered steps through a wizard, checkout, or onboarding sequence |
| Form interactions | "Enter 'alex@example.com' into the Email field," "Click the 'Submit' button" |
| DOM assertions | "The heading 'Order Confirmed' is visible," "The URL changes to /confirmation" |
| Iframe content | Note the iframe boundary: "The payment form is inside a Stripe iframe (`#stripe-payment-iframe`)" |
| Alternate paths | "Using the same customer but with country set to Canada, test the international surcharge" |
| Known bugs | "This test is expected to fail because the error message is missing the word 'is'" |
| Variable/LLM content | "The recommendation text matches the pattern: fiction, mystery, or thriller" |
| Flow-wide checks | "Throughout this entire flow, there should be no JavaScript console errors" |
| Shared setup | "This test requires the checkout flow (tests 1-3) to have completed first" |
| Pre-set state | "The user is already logged in," "The feature flag 'dark_mode_v2' is enabled" |
| Network mocking | "If the API returns a 500 error, the page should show 'Something went wrong'" |
| Device testing | "Test this on iPhone 14" |
| Cleanup | "After the test, delete the account that was created" |

## What the test framework cannot handle

Do **not** write documents for these — they need different tools:

| Category | Example | Why | What to use instead |
|----------|---------|-----|---------------------|
| Cross-run comparison | "Run it twice and compare the results" | The framework tests one run at a time | Custom test code |
| Performance | "The page should load in under 2 seconds" | It tests *what* happens, not *how fast* | Lighthouse, WebPageTest |
| Visual regression | "The page should look like this screenshot" | It tests DOM text, not pixels | Percy, Chromatic, Playwright screenshots |
| Accessibility | "Screen readers should announce the form labels" | Needs specialized tooling | axe-core, pa11y |
| API testing | "The endpoint returns a 200 with these fields" | It tests the UI, not the API | Postman, REST Assured |
| Conditional branching | "If the user picks X, show screen A; if Y, show screen B" | Each test is a single linear flow | Write one test per branch |

## Rules for writing documents

### 1. One flow per test case

Each test case should describe one linear path through the application. Don't combine multiple scenarios into one test case.

**Bad:** "Test the checkout flow with valid and invalid cards"
**Good:** Two separate test cases — "Test checkout with a valid card" and "Test checkout with an expired card"

For alternate paths that share most of the same steps, note which field differs: "Same as the happy path, but with `shipping.country = CA`."

### 2. Use exact DOM text for selectors

Use the precise text that appears in the UI. Don't paraphrase.

**Bad:** "Click the submit button"
**Good:** "Click the 'Place Order' button"

**Bad:** "Check the science fiction option"
**Good:** "Click the 'Science Fiction' checkbox"

### 3. Include DOM identifiers alongside display text

If you know the `data-*` attributes, `aria-label`, or `id` of an element, include them in parentheses after the display text. This eliminates ambiguity when multiple elements have similar labels.

**Bad:** "Select the nausea option"
**Good:** "Click the 'Nausea' checkbox (`data-category=\"nausea\"`)"

If you don't know the DOM identifiers, that's OK — write the display text and note that identifiers need to be confirmed against the live site.

### 4. Write concrete expected outcomes

Every test case must have at least one expected outcome, and it must be specific enough to assert in code.

**Bad:** "The page updates"
**Good:** "The URL changes to `/checkout/confirmation`"

**Bad:** "An error appears"
**Good:** "A red error message reading 'Email is required' appears below the email field"

**Bad:** "The results are correct"
**Good:** "The heading 'Science Fiction & Fantasy' is visible and at least 3 product cards are shown"

### 5. Note iframe boundaries prominently

If any part of the flow lives inside an iframe (Stripe checkout, PayPal button, embedded form, OAuth consent screen), **say so at the top of the test case**, not buried in an appendix.

**Example:** "The payment form is hosted inside a cross-origin Stripe iframe (`#stripe-payment-iframe`). All payment-related actions target elements inside that iframe."

This is critical because:
- Without this note, every selector inside the iframe will silently fail
- It causes *all* tests to fail at once with no obvious cause
- It's the single most common source of test debugging time

If the flow exits the iframe at any point (e.g., a confirmation page outside the payment form), note where the transition happens.

### 6. Use fixture tables for shared test data

When multiple test cases use the same persona or input data, define it once in a table at the top of the document instead of repeating values in every test case.

**Example:**

| Field | Value |
|-------|-------|
| First name | Alex |
| Last name | Rivera |
| Email | alex-test@example.com |
| Address | 123 Main St, Portland, OR 97201 |
| Card | 4242424242424242, exp 12/28 |

Then reference it: "Using the Alex Rivera fixture, complete the checkout flow."

Use the actual values the form accepts, not display-friendly versions:
- Phone: `5035551234` not `(503) 555-1234` (if the form rejects formatted input)
- Date: `1990-03-15` not `March 15, 1990` (if the form uses ISO format)

### 7. Document known bugs as expected failures

If you know a test will fail because of a current bug, include it as a test case with an explicit note:

**Example:** "Expected failure: the error message reads 'Email already taken' but should read 'This email is already taken.' — the word 'This' is missing."

This creates a regression guard: when the bug is fixed, the test flips from "expected failure" to "real failure," signaling that the guard can be removed.

### 8. Define scope boundaries

At the top of the document, state what is in scope and what is out:

**Example:**
- In scope: checkout happy path (5 screens), one customer persona, desktop viewport
- Out of scope: mobile layouts, accessibility, performance, error recovery beyond validation messages, payment processor edge cases

### 9. Don't mix test definitions with implementation advice

Keep *what to test* separate from *how to build the tests*. Implementation details like file structures, framework choices, or config snippets should go in a separate section or document, not interleaved with test cases.

**Bad:**
```
## Test 1: Login

Create a file `tests/login.spec.ts` using Playwright Test. Configure the base URL 
in `playwright.config.ts`. Then test that the user can log in with valid credentials.
```

**Good:**
```
## Test 1: Login with valid credentials

- Enter 'alex@example.com' into the 'Email' field.
- Enter 'SecurePass123!' into the 'Password' field.
- Click the 'Sign In' button.
- Expected: The URL changes to /dashboard.
- Expected: The heading 'Welcome back, Alex' is visible.
```

### 10. Verify claims against the live site

If you're writing from memory, design docs, or mockups, note which claims are assumed vs. verified. Documents often contain predictions that don't match reality:

- A form might accept different input formats than expected
- A page might have extra interstitial screens not in the design
- Labels and button text may have changed since the mockup

Mark unverified claims: "Assumed: the phone field accepts formatted input — verify against the live site."

## Document template

```markdown
# [Flow Name]

## Scope
- In scope: [what's covered]
- Out of scope: [what's not]

## Test data
| Field | Value |
|-------|-------|
| ... | ... |

## Architecture notes
- [Note any iframes, cross-origin transitions, or app boundaries]
- [Note any authentication requirements]

## Test 1: [Short description]

- Action: [what the user does — use exact button/link text]
- Expected: [what should happen — specific, assertable]

## Test 2: [Short description]

- Action: ...
- Expected: ...

## Known issues
- [Bug description] — expected to fail until fixed
```

## Checklist

Before finalizing a document, verify:

- [ ] Each test case describes one linear flow (no branching)
- [ ] Every action uses exact DOM text (not paraphrased labels)
- [ ] Every expected outcome is specific enough to assert (not "it works")
- [ ] Iframe/architecture boundaries are noted prominently
- [ ] Shared test data is in a fixture table, not repeated per test
- [ ] Known bugs are documented as expected failures
- [ ] Scope boundaries are defined (in scope / out of scope)
- [ ] Unverified claims are marked as assumptions
- [ ] No implementation advice is mixed into test definitions
