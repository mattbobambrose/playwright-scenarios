---
name: crawl-site
description: Crawl a website starting from a URL to discover user flows, and write scenarios to <SCENARIO_DIR>/crawl/ (read-only traversal; never fills forms or clicks destructive buttons). Accepts an optional natural-language description of what to focus on or how thorough to be. Complementary seed-generator to /record-scenario.
summary: Read-only crawl of a site. Accepts natural-language descriptions ("focus on checkout flow") to guide scope. A bare URL crawls with default settings (depth 1, max 10 scenarios, no filtering). Emits scenarios to `<scenario_dir>/crawl/`.
signature: /crawl-site <start-url> [description] [--depth=N] [--max-scenarios=N]
arguments:
  - name: start-url
    description: Required. The URL to start crawling from. Optionally followed by a natural-language description of what to crawl and/or flags. Supported flags - --depth=N (override interpreted depth; max 3), --max-scenarios=N (cap emitted scenarios; default 10).
    required: true
---

# Crawl Site

Drive a site from a starting URL, observe its interactive surface, and write scenarios that represent **plausible user flows** (not a page enumeration). The output is written to `<SCENARIO_DIR>/crawl/` and feeds the `/review-scenario` → `/scenario-to-tests` pipeline. The scenario is the canonical artifact. If the user wants to delete crawl-emitted scenarios they don't care about (or hand-edit them) before running `/review-scenario`, they do so in place.

This command is strictly **read-only**: it navigates, scrolls, and observes, but never fills inputs, never submits forms, and never clicks buttons whose text suggests state change (submit, delete, buy, subscribe, sign up, log in, etc.). For flows that require interaction, use `/record-scenario`.

## Argument parsing

Split the argument string into three parts:

- **Start URL** (required) — the first token that starts with `http://` or `https://`.
- **Flags** (optional) — tokens starting with `--`:
  - `--depth=N` — explicit depth override. Clamp to `[1, 3]`.
  - `--max-scenarios=N` — explicit cap on scenarios emitted.
- **Description** (optional) — everything else, joined into one string. This is a natural-language instruction describing what to focus on or how thorough to be.

Any unknown `--`-prefixed token → error before doing any work. Missing start URL → error.

**Examples:**

```
/crawl-site https://mysite.com
/crawl-site https://mysite.com --depth=3
/crawl-site https://mysite.com focus on the checkout flow for a first-time buyer
/crawl-site https://mysite.com thorough crawl of all product-related pages --max-scenarios=15
/crawl-site https://mysite.com shallow overview of the main navigation
```

If a description is provided, Phase 1.5 interprets it. Otherwise, fall back to default behavior (structural crawl, depth 1, max 10 scenarios, no filtering), applying any flag overrides if present.

## Phase 0: Load project config and preflight

### 0a. Load config

Invoke `loading-config` to resolve `<SCENARIO_DIR>`. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair.

### 0b. `playwright-cli` preflight

Run `playwright-cli --version` (timeout: 5s); fall back to `npx --no-install playwright-cli --version`. If both fail, abort with:

> `playwright-cli` is not available. Install it with `npm install -g @playwright/cli@latest` or make sure `npx playwright-cli` works in this project. See the README's "Host Project Setup" section for details.

### 0c. Prepare crawl directory

Ensure `<SCENARIO_DIR>/crawl/` exists; create it if not.

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

## Phase 1.5: Interpret the description (if provided)

If no description was given, skip this phase — use defaults (depth 1, max 10, no filtering).

If a description was provided, interpret it in the context of the Phase 1 inventory:

### Classify the intent

- **Goal-oriented** — the user wants specific flows covered. Examples: "map the checkout flow", "find all forms", "focus on auth pages", "explore the product catalog". Filter the Phase 1 inventory to links/elements matching the goal.
- **Intensity-oriented** — the user wants a certain thoroughness. Examples: "shallow overview", "deep dive", "cover everything", "just the main pages". Adjust the effective depth and max-scenarios values.
- **Hybrid** — the user describes both. Example: "thorough crawl of the checkout flow". Apply both goal filtering and intensity adjustment.

### Determine effective parameters

Based on the interpretation, set:

- **Effective depth** — "shallow" / "overview" → 1; "moderate" / no intensity signal → 2; "deep" / "thorough" / "everything" → 3.
- **Effective max-scenarios** — "just the main ones" → 5; no signal → 10; "comprehensive" / "everything" → 20.
- **Focus filter** — a list of keywords/concepts extracted from the goal (e.g., "checkout", "cart", "payment", "shipping" for "focus on the checkout flow"). Used to rank and filter in Phase 2.

If `--depth` or `--max-scenarios` flags were explicitly set, they override the interpreted values. The description informs, the flags constrain.

### Show the crawl plan

Before proceeding, show the user a summary of the interpreted plan:

> Based on your description "*focus on the checkout flow for a first-time buyer*", I'll:
> - Follow links related to: cart, checkout, shipping, payment, confirmation
> - Deprioritize: blog, about, careers, support pages
> - Depth: 3 (enough to cover cart → checkout → payment → confirmation)
> - Max scenarios: 8
>
> Proceed?

Use `AskUserQuestion` with options: `Yes, proceed` (Recommended), `No, let me adjust`. If the user adjusts, they can provide a revised description or explicit flags, and the interpretation runs again.

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

When a description with a **focus filter** is active, ranking changes:

1. Flows matching the focus filter keywords (regardless of DOM position).
2. Primary-nav items (not already matched above).
3. Hero / primary CTAs (not already matched above).
4. Auth-gate entry points.
5. In-content feature links.
6. Footer (capped at one aggregate scenario).

When no description is provided, use the default ranking:

1. Primary-nav items.
2. Hero / primary CTAs.
3. Auth-gate entry points.
4. In-content feature links.
5. Footer (capped at one aggregate scenario).

Flows not matching the focus filter are **deprioritized, not dropped** — they still appear if the max-scenarios cap has room after the focused flows.

If the start page is behind an auth gate (detected by a prominent login form or redirect to `/login`), emit a single scenario naming the gate and **stop crawling** — don't attempt to proceed.

## Phase 3: Walk each selected flow (parallel subagents)

Each flow is an independent same-origin navigation with no shared state. Launch subagents in **batches of at most 5 concurrent** — the same pattern used by `/review-scenario` and `/scenario-to-tests`. If there are more than 5 flows, process them in sequential batches.

Each subagent receives one flow and performs these steps (only when effective depth >= 1):

1. Navigate to the flow's destination via `playwright-cli goto <destination-url>` (don't synthesize the click; direct navigation is more reliable and still read-only).
2. Take a snapshot of the destination.
3. Record what's verifiable *without interaction*:
   - Destination URL after redirects (matches expected? differs?).
   - Page title / main heading text.
   - One or two prominent visible elements (a hero heading, a form label, a banner).
4. If effective depth >= 2, repeat the inventory-and-rank process on the destination (applying the same focus filter if present), but do not recurse beyond the effective depth.
5. Return the observations to the main thread. Include: URLs discovered at this level, URLs crawled, URLs skipped, and the maximum depth seen in outbound links (for the "max_depth_available" estimate).

Do **not** fill forms. Do **not** click buttons. If a page obviously requires login to proceed (login wall, 401 / 403), record that fact as the scenario's expected outcome and move on.

## Phase 4: Write scenarios

For each retained flow, write one scenario file to `<SCENARIO_DIR>/crawl/<flow-name>.md`.

### Naming

Generate kebab-case filenames from the flow. Examples:

| Flow | Filename |
|------|----------|
| Nav to Pricing | `nav-to-pricing.md` |
| Hero CTA → Signup landing | `hero-cta-signup.md` |
| Footer navigation inventory | `footer-nav-inventory.md` |
| Nav to Login (auth gate) | `nav-to-login.md` |

If a scenario by that name already exists under `<SCENARIO_DIR>/crawl/`, increment the numeric suffix (`-v2`, `-v3`, ...) until a free name is found. Do not silently overwrite.

### Format

Use the flat scenario format documented in the `authoring-scenarios` skill. A representative draft:

```markdown
# Nav To Pricing

**URL:** /

Navigating from the homepage to the Pricing page via the primary nav.

> Generated by `/crawl-site` — "focus on the checkout flow for a first-time buyer". Review and edit before feeding into `/scenario-to-tests`.

## Test 1: Click the 'Pricing' nav link

- **Action:** Click the 'Pricing' link in the primary nav.
- **Expected:** The URL changes to `/pricing`.
- **Expected:** The heading "Pricing" is visible.
```

Rules for the generated content:

- Preserve **concrete selector text** (exact link text, exact heading text) — `/review-scenario` needs this to verify against the live site.
- Use the imperative/descriptive voice the `authoring-scenarios` skill mandates.
- Always include a provenance blockquote. If a description was provided, include it: `> Generated by /crawl-site — "<description>"`. If no description, use: `> Generated by /crawl-site`.
- For footer-aggregate scenarios, include a minimal Action bullet (`- **Action:** Scroll to the page footer`) followed by the observed links as Expected bullets (`- **Expected:** The footer contains a link to "About"`, etc.) — every test requires at least one Action and one Expected per the `authoring-scenarios` format.
- Auth-gate scenarios should have a single Expected asserting the user is redirected to or sees the login form — not a speculative login flow.

## Phase 5: Write crawl metadata

After all scenarios are written, write (or append to) a metadata file at `<SCENARIO_DIR>/crawl/.crawl-meta.json`. This file records crawl history so `/scenario-status` can report coverage completeness.

If the file exists, read it, append the new crawl entry to the `crawls` array, and write it back. If it doesn't exist, create it with a single-entry array.

```json
{
  "crawls": [
    {
      "timestamp": "2026-04-21T14:30:00Z",
      "start_url": "https://mysite.com",
      "description": "focus on the checkout flow for a first-time buyer",
      "effective_depth": 3,
      "effective_max_scenarios": 8,
      "urls_discovered": 22,
      "urls_crawled": 15,
      "urls_skipped": 7,
      "scenarios_written": 6,
      "flow_types": {
        "nav": 2,
        "hero_cta": 1,
        "content": 2,
        "footer": 1,
        "auth": 0
      },
      "max_depth_reached": 3,
      "max_depth_available": 5
    }
  ]
}
```

Fields:
- `description` — the user's natural-language description, or `null` if none was given.
- `effective_depth` / `effective_max_scenarios` — the values used (after interpretation + flag overrides).
- `urls_discovered` — total same-origin links found across all levels.
- `urls_crawled` — links actually navigated to.
- `urls_skipped` — links deprioritized or cut by the cap.
- `flow_types` — count of flows per type that were written as scenarios.
- `max_depth_reached` — deepest level the crawl actually visited.
- `max_depth_available` — estimated maximum depth of the site based on outbound links seen at the deepest level crawled (if the deepest pages still had outbound links, the site goes deeper).

## Phase 6: Report

Print a summary table listing every scenario written:

| Scenario | Flow type | Destination | Notes |
|----------|-----------|-------------|-------|

If a description was given, also report:
- What the description was interpreted as (goal, intensity, or hybrid).
- Which focus keywords were used.
- How many flows matched vs. didn't match the filter.

Finish with next-step pointers for the user:

1. Review a scenario in place: `cat <SCENARIO_DIR>/crawl/<name>.md`. Hand-edit or delete any you don't want.
2. Run `/review-scenario` to audit the remaining scenarios against the live site.
3. Run `/scenario-status` to see overall coverage including this crawl's contribution.

Do **not** auto-chain into `/review-scenario` — the user decides when to run it.
