---
icon: lucide/pencil
---

# Writing Effective Input Documents

If you're writing a document that will feed into this plugin (either hand-authored as scenario markdown or used as a reference for `/record-scenario`), these patterns produce the best results.

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

**URL:** https://bookstore.example.com/checkout
**Iframe:** #stripe-payment-iframe

The payment form is hosted inside a cross-origin Stripe iframe.
All payment-related actions below target elements inside that iframe.

## Test 1: Enter card details
...
```

The generated test code will use `page.frameLocator('#stripe-payment-iframe')` instead of `page` for all selectors inside the boundary. If the document doesn't mention the iframe, the generated tests will target the top-level page and fail on every assertion.

When the flow exits the iframe (e.g., a confirmation page outside the payment form), add `**Iframe:** none` at the transition point.
