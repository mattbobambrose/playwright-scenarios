---
name: evaluate-doc
description: Evaluate any document (test plan, requirements doc, meeting notes, acceptance criteria) against the playwright-scenarios plugin's capabilities. Reports what can be directly converted to scenarios, what needs modification, and what is out of scope entirely. Use when the user provides a document and wants to know how well it maps to the scenario pipeline, or when the user asks "can we test this?" or "what would need to change?" about an existing document.
---

# Evaluate Doc

Read a user-provided document (test plan, requirements doc, acceptance criteria, meeting notes — any format) and produce a structured testability report. This skill is advisory: it reads and reports, but never writes scenario files. The user decides what to act on.

## When to use

- User says "evaluate this doc" / "can we test this?" / "what can we cover?" / "review this doc for testability"
- User provides or references a QA document and asks how it maps to the scenario pipeline
- Before converting a large document into scenarios, to identify gaps upfront

## Inputs

The user provides one or more file paths or pastes content inline. Read every referenced document in full before starting analysis.

## Analysis procedure

### Step 1: Inventory test cases

Walk the document and extract every discrete test case, acceptance criterion, or testable assertion. For each, record:

- A short identifier (the document's own numbering if it has one, otherwise invent `TC-1`, `TC-2`, etc.)
- A one-line summary of what's being tested
- The document's stated expected behavior

### Step 2: Classify each test case

For each test case, assign one of these categories:

| Category | Meaning |
|----------|---------|
| **direct** | Can be expressed as a scenario Action/Expected pair with no modification. The test case describes a UI interaction and a DOM-observable outcome. |
| **needs-changes** | Expressible as a scenario, but the document needs modification first — e.g., display text needs DOM identifiers, vague selectors need concretizing, assumed behavior needs live-site verification. |
| **extended-tag** | Expressible using one of the extended scenario tags (`Fixture`, `Prerequisite`, `Assert throughout`, `Expected failure`, `Expected (regex)`) but the document doesn't use scenario format yet. |
| **out-of-scope** | Cannot be expressed in the scenario format at all — e.g., cross-run comparison, visual regression, a11y, performance, network-layer, or requires capabilities Playwright doesn't have. |

### Step 3: Identify document-level issues

Beyond individual test cases, flag document-wide problems that will cause friction during conversion:

- **Missing iframe / architecture boundaries.** Does the document mention cross-origin iframes, app transitions, or embedded third-party widgets? If not but the URL suggests them (Stripe, PayPal, OAuth providers), flag it as a likely omission.
- **Display text without DOM identifiers.** Does the document use human-readable labels ("Science Fiction & Fantasy") without corresponding `data-*`, `aria-label`, or `role` identifiers? Count how many test cases are affected.
- **Assumed behaviors.** Does the document assert behaviors that sound like predictions rather than observations ("the system will swap the oldest selection")? Flag these for live-site verification via `/review-scenario`.
- **Phase/step numbering drift risk.** Does the document number screens or steps sequentially? If so, note that these often drift from the live site due to interstitials, intro screens, or pages outside the expected container.
- **Mixed concerns.** Does the document interleave test definitions with implementation recommendations (file structures, config settings, framework choices)? Note which sections are test cases vs. toolchain guidance.
- **Missing fixture data.** Does the document reference specific input values (names, emails, addresses) without a consolidated fixture table? If values are scattered across test cases, suggest a fixture table.
- **Scope boundaries.** Does the document define what's in and out of scope? If not, flag the risk of scope creep.

### Step 4: Map extended tags

For test cases classified as `extended-tag`, identify which tag applies:

| Document pattern | Scenario tag |
|-------------|--------------|
| "This test is expected to fail because..." / known bug | `**Expected failure:** <reason>` |
| "Text should contain one of X, Y, or Z" / nondeterministic content | `**Expected (regex):** <pattern>` |
| "Check this across the entire flow" / invariant | `**Assert throughout:** <assertion>` |
| "Run the login flow first" / shared setup dependency | `**Prerequisite:** <scenario-name> (Tests N-M)` |
| Persona table / structured test data | `**Fixture:** <path>` |
| "The content should match a pattern, not exact text" | `**Expected (regex):** <pattern>` |
| "The form is inside an iframe" / cross-origin embed | `**Iframe:** <selector>` |
| "If the user ships internationally..." / alternate path with fixture override | `**Branch:** <field> = <value>` (requires `**Fixture:**`) |
| "What if the API returns 500?" / error state testing | `**Intercept:** <url-pattern> → <status> [body]` |
| "User is already logged in" / pre-set auth state | `**Cookie:** <name>=<value>` |
| "Feature flag is enabled" / client-side state | `**Storage:** <key>=<value>` |
| "Test on mobile" / device-specific behavior | `**Device:** <preset>` |
| "This flow takes a long time" / slow operation | `**Timeout:** <ms>` |
| "Delete the test account afterwards" / cleanup step | `**Cleanup:** <action>` |

### Step 5: Suggest document improvements

For test cases classified as `needs-changes`, produce a specific suggestion:

- If the selector is vague → "Add the exact button/link text or `data-qa-*` attribute"
- If the expected behavior is assumed → "Verify against the live site with `/review-scenario`"
- If the document uses display text as a data value → "Add the DOM identifier alongside: `'Science Fiction' (data-category=\"sci-fi\")`"
- If an iframe boundary is missing → "Note the iframe host element and origin at the top of the relevant section"
- If a test case mixes what-to-test with how-to-implement → "Move the implementation detail to a separate section"

## Output format

Produce a report with these sections, in this order:

### 1. Summary

One paragraph: how many test cases were found, how many are direct/needs-changes/extended-tag/out-of-scope, and an overall assessment ("this document converts cleanly" or "significant rework needed" or "good coverage but N items are out of scope").

### 2. Test case table

| # | Summary | Category | Tag / Issue | Suggested change |
|---|---------|----------|-------------|------------------|

One row per test case. The "Tag / Issue" column names the extended tag for `extended-tag` items, or the specific issue for `needs-changes` items. The "Suggested change" column is blank for `direct` items.

### 3. Document-level issues

Bulleted list of document-wide problems from Step 3, each with a one-line recommendation.

### 4. Out-of-scope items

For each `out-of-scope` test case, explain *why* it's out of scope and *where* it should live instead (custom test code, a11y suite, API tests, etc.). Use the same categories as the "What It Cannot Test" table in the README.

### 5. Conversion roadmap

A numbered list of recommended next steps, ordered by priority:

1. Fix document-level issues (iframe notes, fixture table, etc.)
2. Resolve `needs-changes` items (add DOM identifiers, verify assumptions)
3. Convert `direct` items to scenario markdown (hand-write or use `/record-scenario`)
4. Convert `extended-tag` items using the appropriate tags
5. Handle `out-of-scope` items in their respective test suites

## What this skill does NOT do

- It does not write or modify scenario files — use the `authoring-scenarios` skill or `/record-scenario` for that.
- It does not open a browser or verify claims against the live site — that's `/review-scenario`'s job.
- It does not generate test code — that's `/scenario-to-tests`.
- It does not modify the input document — suggestions are reported, not applied.
