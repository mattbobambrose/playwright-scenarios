---
icon: lucide/pencil
---

# Writing Effective Test Documents

If you're writing a document that will feed into this plugin (either hand-authored as scenario markdown or used as a reference for `/record-scenario`), these patterns produce the best results.

## Including the guide in a prompt

When you have an LLM draft a test document, give it the authoring rules together with a description of the flow to document. Most LLMs can read [TEST_DOC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md) straight from its URL, so reference the link rather than pasting the whole file into the prompt:

```
Read the test-document authoring rules at
https://raw.githubusercontent.com/mattbobambrose/playwright-scenarios/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md

Follow those rules as closely as you can — don't critique them or suggest
improvements, just apply them. Then write a test document called "checkout-flow"
for the checkout flow of my app, covering the cart, shipping and payment entry,
order placement, and the confirmation page.
```

!!! note "Link to the raw Markdown"
    The URL above is for the **raw** file (`raw.githubusercontent.com`) so an LLM fetching it will get plain Markdown, not [GitHub's HTML page](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md). If your LLM can't fetch URLs, paste the full contents of `TEST_DOC_GUIDE.md` into the prompt in place of the URL — the rest of the prompt is unchanged.

## What works well

- **Fixture tables mapping screens to exact field values.** A canonical persona table (screen → field → value) becomes the single source of truth for test data. It eliminates ambiguity about what to enter on each screen and translates directly into `**Fixture:**` references.
- **Explicit scope boundaries.** Define what's in scope (e.g., "5 checkout screens, one customer persona") and what's out (edge cases, a11y, performance). This prevents scope creep and gives a clear Definition of Done.
- **Numbered, discrete test cases.** Each test should have a single purpose that maps to one scenario file or one `## Test N:` block. No overlap, no gaps.
- **Known-bug documentation as test cases.** Listing known copy bugs or behavioral issues as expected-failure test cases ("assert the desired text, mark as expected failure") creates built-in regression guards that flip to real failures when bugs are fixed.
- **Concrete selector text.** Use the exact link text, button label, heading text, or `aria-role` name that appears in the DOM. Scenarios that say "Click the **'Log In'** link" produce more reliable tests than "click the login button."

## What doesn't work well

- **Assumed behaviors not verified against the live site.** Documents written from memory or design mockups often contain claims that don't match reality (e.g., predicting a silent swap when the actual behavior is a validation error). Always run `/review-scenario` to ground-truth claims against the live site before generating tests.
- **Display text instead of DOM identifiers.** If your document says "Science Fiction & Fantasy" but the actual selector is `data-category="sci-fi-fantasy"`, every value needs translation during implementation. Include `data-*` attributes or other DOM identifiers alongside display text when possible.
- **Missing iframe/architecture notes.** If the form lives inside a cross-origin iframe, or the flow transitions between separate apps, note this in the document. Implementation-critical architecture should be documented even if it's not a test assertion — one line like "The checkout form is hosted inside a cross-origin Stripe iframe" saves hours of debugging.
- **Phase numbers that drift from reality.** If your document numbers 23 phases but the live flow has interstitials, intro screens, or pages outside the expected container, the mapping between document phases and actual screens requires careful reconciliation. Verify phase numbering against the live site.
- **Mixing test definitions with toolchain recommendations.** Keep the *what to test* separate from the *how to implement*. Suggested file structures, config snippets, and framework choices are helpful context but shouldn't be interleaved with test case definitions — the plugin handles implementation decisions via its config.

## Example: good vs. bad snippets

### Bad

Vague selectors, display text as data values, no DOM identifiers:

```markdown
## Test 3: Filter by genre

- **Action:** Check the science fiction option.
- **Action:** Check the fantasy option.
- **Action:** Click Apply.
- **Expected:** The results update.
```

### Good

Exact selector text, DOM identifiers alongside display text, concrete expected outcome:

```markdown
## Test 3: Filter by genre

- **Action:** Click the 'Science Fiction' checkbox (`data-category="sci-fi"`).
- **Action:** Click the 'Fantasy' checkbox (`data-category="fantasy"`).
- **Action:** Click the 'Apply Filters' button.
- **Expected:** The URL changes to `/books?genre=sci-fi,fantasy`.
- **Expected:** The heading 'Science Fiction & Fantasy' is visible.
```

!!! tip "Key differences"
    The good version uses the exact checkbox label (`'Science Fiction'`) that maps to a `getByRole` selector, includes the `data-category` attribute for disambiguation, and asserts a specific URL and heading rather than "the results update."

## Cross-origin iframes and app boundaries

If any part of the flow under test lives inside a cross-origin iframe or transitions between separate applications, **document this prominently** — not buried in an architecture appendix, but right next to the URL or the first test case that enters the iframe.

!!! warning "Why this matters"
    - Playwright requires an explicit `frameLocator()` call to interact with iframe content. Without it, every selector silently fails to match.
    - Cross-origin iframes (e.g., a Stripe checkout, a PayPal button, an OAuth consent screen) can't be accessed via `page.frame()` in some configurations — they need `page.frameLocator()` with the iframe's `src` or `name` attribute.
    - A single missing iframe note causes *every test in the flow* to fail simultaneously with "element not found" errors that give no hint about the real problem.

In a scenario file, note the boundary using the `**Iframe:**` tag:

```markdown
# Checkout Flow

**URL:** https://mysite.com/checkout
**Iframe:** #stripe-payment-iframe

The payment form is hosted inside a cross-origin Stripe iframe.
All payment-related actions below target elements inside that iframe.

## Test 1: Enter card details
...
```

The generated test code will use `page.frameLocator('#stripe-payment-iframe')` instead of `page` for all selectors inside the boundary. If the document doesn't mention the iframe, the generated tests will target the top-level page and fail on every assertion.

When the flow exits the iframe (e.g., a confirmation page outside the payment form), add `**Iframe:** none` at the transition point.

## Full authoring rules

The patterns above cover the highest-leverage cases. The complete authoring rule set lives in [`TEST_DOC_GUIDE.md`](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md), which you hand to your LLM when drafting a test document. It covers everything here plus:

- **Async/loading transitions** — name the observable end-condition (a spinner appearing then disappearing, a button enabling) instead of relying on implicit waits.
- **Modal and dialog boundaries** — qualify selectors to "inside the modal" once a dialog opens; note where it closes.
- **Navigation type** — say whether an action triggers a same-tab load, a client-side route change, a new tab, a download, or an external redirect.
- **Deterministic test data** — for resource-creating flows (signup, account creation), use stably-suffixed or timestamped values so reruns don't collide.
- **Per-test preconditions** — keep setup state (auth, feature flags, seeded data) in a dedicated `Preconditions:` block, separate from the action steps.

`TEST_DOC_GUIDE.md` also lists what the framework can and cannot handle (CAPTCHA, OTP/email verification, native browser dialogs, hardware integration are all out of scope) and ends with a self-applied checklist.
