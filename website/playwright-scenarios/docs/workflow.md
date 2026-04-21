---
icon: lucide/git-branch
---

# Workflow

## The goal: reviewed scenarios

Every workflow in this plugin converges on the same destination — a **reviewed scenario file** that `/scenario-to-tests` can turn into executable test code:

``` mermaid
graph LR
    A[reviewed scenario] -->|"/scenario-to-tests"| B[test file]
    B -->|run| C[pass / fail]
    C -->|"/scenario-status"| D[health dashboard]
```

```
/scenario-to-tests checkout-flow
```

1. Resolves config (test directory, language, framework, base class).
2. Explores the live site to observe actual behavior.
3. Generates one test file per scenario.
4. Runs the tests and fixes failures.

Use `--dry-run` to write the files without running them. Use `/scenario-status` to monitor health across all scenarios.

The question is: **how do you get a reviewed scenario?** Four paths, depending on where you're starting from.

---

## Path A: Generate specs with an LLM

You're starting from scratch and using an LLM (ChatGPT, Claude, Gemini, etc.) to write your QA specs.

``` mermaid
graph LR
    A[Paste SPEC_GUIDE\ninto your LLM] --> B[LLM writes spec]
    B --> C["/doc-to-scenarios"]
    C --> D["drafts/"]
    D -->|promote| E[scenario]
    E -->|"/review-scenario"| F[reviewed scenario]
```

1. **Paste [SPEC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/SPEC_GUIDE.md) into your LLM's context** — system prompt, custom GPT instructions, or the start of a conversation. This teaches the LLM the rules *before* it writes anything.
2. **Ask the LLM to write your spec.** Because it already knows what the test framework can handle, what format to use, and what pitfalls to avoid, the output should be clean on the first pass.
3. **Run `/doc-to-scenarios`** to convert. The evaluation step will mostly confirm the spec is already well-formed.
4. **Promote** drafts out of `drafts/` and **run `/review-scenario`** to verify against the live site.

This path is **front-loaded**: you invest in the LLM's instructions once, and the output needs little to no revision. The `evaluate-doc` step becomes a rubber stamp rather than a feedback loop.

---

## Path B: Migrate existing specs

You already have QA documents or user stories that weren't written with this framework in mind.

``` mermaid
graph LR
    A[Existing spec] --> B["evaluate-doc"]
    B --> C{Issues?}
    C -->|Yes| D[Fix spec in place]
    D --> A
    C -->|No| E["/doc-to-scenarios"]
    E --> F["drafts/"]
    F -->|promote| G[scenario]
    G -->|"/review-scenario"| H[reviewed scenario]
```

1. **Run `evaluate-doc`** against your document. It classifies each test case as direct, needs changes, extended tag, or out of scope.
2. **Fix issues in place.** The evaluation report tells you exactly what to change — vague selectors, missing iframe notes, display text without DOM identifiers, untestable assertions.
3. **Re-evaluate** until the report is clean. Each round narrows the gap.
4. **Run `/doc-to-scenarios`**, then **promote** and **review**.

This path is **iterative**: `evaluate-doc` acts as a feedback loop that guides you toward a testable document.

---

## Path C: Record a flow in a browser

You know the flow and want to capture it by demonstrating it.

``` mermaid
graph LR
    A[Start URL] --> B["/record-scenario"]
    B --> C[Playwright codegen opens]
    C --> D[You drive the browser]
    D --> E[scenario]
    E -->|auto-chains| F["/review-scenario"]
    F --> G[reviewed scenario]
```

```
/record-scenario checkout-flow
```

1. Prompts for a start URL.
2. Opens Playwright codegen — you drive the browser.
3. Converts the recording into a scenario file.
4. Auto-chains into `/review-scenario` (unless `--no-review`).

Best for interactive flows (form fills, logins) where watching the flow is faster than writing it. This is the fastest path to a reviewed scenario — no drafts, no promotion step.

---

## Path D: Crawl a site autonomously

You don't know what flows exist and want Claude to discover them. You can describe what to focus on in natural language, or let it crawl broadly.

``` mermaid
graph LR
    A[Start URL + description] --> B["/crawl-site"]
    B --> C[Interpret description]
    C --> D[Show crawl plan]
    D --> E[Walk flows]
    E --> F["drafts/"]
    F -->|promote| G[scenario]
    G -->|"/review-scenario"| H[reviewed scenario]
```

```
/crawl-site https://bookstore.example.com focus on the checkout flow
/crawl-site https://bookstore.example.com shallow overview
/crawl-site https://bookstore.example.com
```

1. Navigates the start page, inventories links and interactive elements.
2. Interprets your description (goal-oriented, intensity-oriented, or hybrid) and shows a crawl plan for approval.
3. Groups and ranks flows, prioritizing those matching your description.
4. Walks each flow (read-only — never fills forms).
5. Writes draft scenarios to `<scenario_dir>/drafts/` and saves crawl metadata for `/scenario-status`.

Best for bootstrapping coverage. The description lets you steer toward specific areas without manual flag-tuning.

---

## How the paths compare

| | Path A | Path B | Path C | Path D |
|---|---|---|---|---|
| **Starting from** | Nothing | Existing docs | Known flow | Unknown site |
| **Who writes the spec** | Your LLM | A human (already written) | You (in a browser) | Claude (autonomous) |
| **Key tool** | SPEC_GUIDE.md | evaluate-doc | /record-scenario | /crawl-site |
| **Feedback loop** | Minimal | Iterative | None | None |
| **Produces drafts?** | Yes | Yes | No (direct scenario) | Yes |
| **Fastest to reviewed scenario** | Medium | Slow (iteration) | Fastest | Medium |

## Common steps

### Promoting drafts

Paths A, B, and D produce drafts under `<scenario_dir>/drafts/`. Commands skip these by default. When a draft is ready:

```bash
mv src/test/scenarios/drafts/checkout-flow.md src/test/scenarios/checkout-flow.md
```

Or pass `--include-drafts` to process them in place.

### Reviewing against the live site

```
/review-scenario checkout-flow
```

1. Opens the URL via `playwright-cli`.
2. Walks each test case and records observations.
3. Tags findings by severity: broken, vague, missing-coverage, style.
4. Launches parallel subagents to rewrite the scenario with fixes.
5. Reports a summary table of what changed.

!!! tip
    Always review before generating tests. Scenarios written from specs or recordings often contain claims that don't match the live site.

## Fixture workflow

When scenarios share test data (personas, addresses, payment details):

1. **Create a fixture:** `/generate-fixture interactive --name=returning-customer`
2. **Reference it in scenarios:** `**Fixture:** fixtures/returning-customer`
3. **Branch for alternate paths:** `**Branch:** shipping.country = CA`

Fixtures are JSON files under `<scenario_dir>/fixtures/`. See the `fixture-format` skill for the schema.

## Quick reference

| If you... | Path |
|-----------|------|
| Are writing specs from scratch with an LLM | **A** — give the LLM `SPEC_GUIDE.md`, then `/doc-to-scenarios` |
| Have an existing spec that might not be testable | **B** — `evaluate-doc` → fix → `/doc-to-scenarios` |
| Know the flow and want to record it | **C** — `/record-scenario` |
| Don't know what flows exist | **D** — `/crawl-site` |
