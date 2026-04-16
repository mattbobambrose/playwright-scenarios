---
name: crawl-site
description: Crawl a website starting from a URL to discover user flows, and write draft scenarios (read-only traversal; never fills forms or clicks destructive buttons). Complementary seed-generator to /record-scenario — useful when you want Claude to explore a site autonomously and propose scenarios for a human to refine.
arguments:
  - name: start-url
    description: Required. The URL to start crawling from. Optionally followed by flags. Supported flags - --depth=N (override the default 1-hop same-origin traversal; max 3), --max-scenarios=N (cap emitted draft scenarios; default 10).
    required: true
---

# Crawl Site

Drive a site from a starting URL, observe its interactive surface, and write draft scenarios that represent **plausible user flows** (not a page enumeration). The output feeds the existing `/review-scenario` → `/scenario-to-tests` pipeline, but because drafts land under `<SCENARIO_DIR>/drafts/`, those commands won't touch them unless the user passes `--include-drafts` or renames the file out of the drafts folder.

This command is strictly **read-only**: it navigates, scrolls, and observes, but never fills inputs, never submits forms, and never clicks buttons whose text suggests state change (submit, delete, buy, subscribe, sign up, log in, etc.). For flows that require interaction, use `/record-scenario`.

## Argument parsing

The first non-flag token is the **start URL** (required). Split the remaining args into **flags**:

- `--depth=N` — how many same-origin hops to traverse from the start page. Default `1` (start page + its direct links). Clamp to `[1, 3]`.
- `--max-scenarios=N` — cap on the number of draft scenarios emitted. Default `10`. If the crawl discovers more candidate flows than the cap, keep the highest-ranked ones (see "Flow ranking" below).

Any unknown `--`-prefixed token → error before doing any work. Missing start URL → error.

## Phase 0: Load project config and preflight

### 0a. Load config

Invoke `loading-config` to resolve `<SCENARIO_DIR>`. Abort on `MALFORMED_CONFIG` and point the user at `/playwright-scenarios-config`.

### 0b. `playwright-cli` preflight

Run `playwright-cli --version` (timeout: 5s); fall back to `npx --no-install playwright-cli --version`. If both fail, abort with:

> `playwright-cli` is not available. Install it with `npm install -g @playwright/cli@latest` or make sure `npx playwright-cli` works in this project. See the README's "Host Project Setup" section for details.

### 0c. Prepare drafts directory

Ensure `<SCENARIO_DIR>/drafts/` exists; create it if not.

## Phase 1: Fetch and inventory the start page

1. Open the start URL via `playwright-cli` (using whichever invocation the preflight confirmed works).
2. Take a snapshot (`playwright-cli snapshot`) and record:
   - The page's canonical URL after any redirects.
   - The page title.
   - All `<a>` elements with their visible text, `href`, and location (nav / hero / in-content / footer).
   - All `<button>` / `[role="button"]` elements with their visible text — **tagged but not clicked**.
   - All `<form>` elements with their visible labels — tagged only, never submitted.
   - Viewport-relevant metadata (is there a mobile nav toggle? a modal? an auth gate?).
3. Classify each link:
   - **same-origin + non-anchor** → candidate for hop.
   - **same-origin anchor (`#foo`)** → skip (in-page jump, not a flow).
   - **different origin** → skip.
   - **`mailto:` / `tel:` / `javascript:`** → skip.

## Phase 2: Identify candidate user flows

A **flow** is a sequence of actions ending on a destination page. For this read-only crawl, each flow is:

```
1. Navigate to <start URL>
2. Click "<link-text>"
3. (implicit destination page loads)
```

Group candidate flows by intent rather than enumerating every link:

- **Primary nav flows** — links in the header / main navigation. One flow per unique nav item.
- **Hero / primary-CTA flows** — prominent in-hero links or buttons-as-links. Often the "marketing funnel" path.
- **In-content feature flows** — links in the main content that point to feature/product/docs pages.
- **Footer flows** — typically lower priority; group into one aggregate "footer navigation is present" scenario rather than one-per-link.
- **Auth-gate / login flows** — where a link points at a login/signup page, record the navigation *to* the auth page but do not attempt the form.

If multiple links on the page point to the same destination, merge them into one flow (prefer the most prominent source — hero > nav > content > footer). Deduplicate by target URL.

### Flow ranking

Rank flows for the `--max-scenarios` cap (descending priority):

1. Primary-nav items.
2. Hero / primary CTAs.
3. Auth-gate entry points.
4. In-content feature links.
5. Footer (capped at one aggregate scenario).

If the start page is behind an auth gate (detected by a prominent login form or redirect to `/login`), emit a single scenario naming the gate and **stop crawling** — don't attempt to proceed.

## Phase 3: Walk each selected flow (parallel subagents)

Each flow is an independent same-origin navigation with no shared state. Launch subagents in **batches of at most 5 concurrent** — the same pattern used by `/review-scenario` and `/scenario-to-tests`. If there are more than 5 flows, process them in sequential batches.

Each subagent receives one flow and performs these steps (only when `--depth >= 1`):

1. Navigate to the flow's destination via `playwright-cli goto <destination-url>` (don't synthesize the click; direct navigation is more reliable and still read-only).
2. Take a snapshot of the destination.
3. Record what's verifiable *without interaction*:
   - Destination URL after redirects (matches expected? differs?).
   - Page title / main heading text.
   - One or two prominent visible elements (a hero heading, a form label, a banner).
4. If `--depth >= 2`, repeat the inventory-and-rank process on the destination, but do not recurse beyond `--depth`.
5. Return the observations to the main thread.

Do **not** fill forms. Do **not** click buttons. If a page obviously requires login to proceed (login wall, 401 / 403), record that fact as the scenario's expected outcome and move on.

## Phase 4: Write draft scenarios

For each retained flow, write one scenario file to `<SCENARIO_DIR>/drafts/<flow-name>.md`.

### Naming

Generate kebab-case filenames from the flow. Examples:

| Flow | Filename |
|------|----------|
| Nav to Pricing | `nav-to-pricing.md` |
| Hero CTA → Signup landing | `hero-cta-signup.md` |
| Footer navigation inventory | `footer-nav-inventory.md` |
| Nav to Login (auth gate) | `nav-to-login.md` |

If a draft by that name already exists under `<SCENARIO_DIR>/drafts/`, append `-v2`, `-v3`, etc. — **do not overwrite**.

### Format

Use the flat scenario format documented in the `authoring-scenarios` skill. A representative draft:

```markdown
# Nav To Pricing

**URL:** /

Navigating from the homepage to the Pricing page via the primary nav.

> Draft generated by `/crawl-site` — no interactions performed. Review and edit before feeding into `/scenario-to-tests`.

## Test 1: Click the 'Pricing' nav link

- **Action:** Click the 'Pricing' link in the primary nav.
- **Expected:** The URL changes to `/pricing`.
- **Expected:** The heading "Pricing" is visible.
```

Rules for the generated content:

- Preserve **concrete selector text** (exact link text, exact heading text) — `/review-scenario` needs this to verify against the live site.
- Use the imperative/descriptive voice the `authoring-scenarios` skill mandates.
- Always include the "Draft generated by `/crawl-site`" blockquote so a reviewer knows the provenance.
- For footer-aggregate scenarios, include a minimal Action bullet (`- **Action:** Scroll to the page footer`) followed by the observed links as Expected bullets (`- **Expected:** The footer contains a link to "About"`, etc.) — every test requires at least one Action and one Expected per the `authoring-scenarios` format.
- Auth-gate scenarios should have a single Expected asserting the user is redirected to or sees the login form — not a speculative login flow.

## Phase 5: Report

Print a summary table listing every draft written:

| Draft | Flow type | Destination | Notes |
|-------|-----------|-------------|-------|

Finish with three next-step pointers for the user:

1. Review a draft: `cat <SCENARIO_DIR>/drafts/<name>.md`
2. Promote a draft out of drafts: `mv <SCENARIO_DIR>/drafts/<name>.md <SCENARIO_DIR>/<name>.md`
3. Run `/review-scenario <name>` once promoted (it will auto-audit against the live site).

Do **not** auto-chain into `/review-scenario` — drafts deserve a human pass first, which is why they live under `drafts/`.
