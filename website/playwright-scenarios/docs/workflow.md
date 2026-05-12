---
icon: lucide/git-branch
---

# Workflow

The plugin's job is to take you from *"I want to test this website"* to *executable tests*. The pipeline has three stages — **author → review → generate** — plus a status command for monitoring.

``` mermaid
graph TD
    A[User wants to<br/>test a website] -->|"4 paths"| B[Scenario]
    B -->|"/review-scenario"| C[Reviewed<br/>scenario]
    C -->|"/scenario-to-tests"| D[Test suite]
    D -->|"/scenario-status"| E[Health<br/>dashboard]
```

Every creation command writes its scenario directly to its own **source partition** — `<scenario_dir>/crawl/`, `<scenario_dir>/record/`, or `<scenario_dir>/convert/`. The scenario is the canonical artifact; if you want to hand-edit or delete some before review, you do so in place.

The question is: **how do you get to a scenario in the first place?** Four paths, depending on where you're starting from.

---

## Path A: Crawl a site autonomously

You don't know what flows exist and want Claude to discover them. You can describe what to focus on in natural language, or let it crawl broadly.

``` mermaid
graph LR
    A[Start URL + description] --> B["/crawl-site"]
    B --> C[Interpret description]
    C --> D[Show crawl plan]
    D --> E[Walk flows]
    E --> F["scenarios/crawl/"]
    F -->|"/review-scenario"| G[reviewed scenario]
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
5. Writes scenarios to `<scenario_dir>/crawl/` and saves crawl metadata for `/scenario-status`.

Best for bootstrapping coverage. The description lets you steer toward specific areas without manual flag-tuning. Delete any crawl-emitted scenarios you don't want before running `/review-scenario`.

---

## Path B: Record a flow in a browser

You know the flow and want to capture it by demonstrating it.

``` mermaid
graph LR
    A[Start URL] --> B["/record-scenario"]
    B --> C[Playwright codegen opens]
    C --> D[You drive the browser]
    D --> E["scenarios/record/"]
    E -->|"/review-scenario"| F[reviewed scenario]
```

```
/record-scenario checkout-flow
```

1. Prompts for a start URL.
2. Opens Playwright codegen — you drive the browser.
3. Converts the recording into `<scenario_dir>/record/<name>.md`.
4. Hand-edit if you want, then run `/review-scenario`.

Best for interactive flows (form fills, logins) where watching the flow is faster than writing it.

---

## Path C: Generate documents with an LLM

You're starting from scratch and using an LLM (ChatGPT, Claude, Gemini, etc.) to write your test documents.

``` mermaid
graph LR
    A[Paste DOC_GUIDE\ninto your LLM] --> B[LLM writes document]
    B --> C["/doc-to-scenarios"]
    C --> D["scenarios/convert/"]
    D -->|"/review-scenario"| E[reviewed scenario]
```

1. **Paste [DOC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/DOC_GUIDE.md) into your LLM's context** — system prompt, custom GPT instructions, or the start of a conversation. This teaches the LLM the rules *before* it writes anything.
2. **Ask the LLM to write your document.** Because it already knows what the test framework can handle, what format to use, and what pitfalls to avoid, the output should be clean on the first pass.
3. **Run `/doc-to-scenarios`** to convert. The evaluation step will mostly confirm the document is already well-formed. Output lands in `<scenario_dir>/convert/`.
4. **Run `/review-scenario`** to verify against the live site (optionally hand-edit the convert-partition scenarios first).

This path is **front-loaded**: you invest in the LLM's instructions once, and the output needs little to no revision. The `evaluate-doc` step becomes a rubber stamp rather than a feedback loop.

---

## Path D: Migrate existing documents

You already have documents that weren't written with this framework in mind.

``` mermaid
graph LR
    A[Existing document] --> B["evaluate-doc"]
    B --> C{Issues?}
    C -->|Yes| D[Fix document in place]
    D --> A
    C -->|No| E["/doc-to-scenarios"]
    E --> F["scenarios/convert/"]
    F -->|"/review-scenario"| G[reviewed scenario]
```

1. **Run `evaluate-doc`** against your document. It classifies each test case as direct, needs changes, extended tag, or out of scope.
2. **Fix issues in place.** The evaluation report tells you exactly what to change — vague selectors, missing iframe notes, display text without DOM identifiers, untestable assertions.
3. **Re-evaluate** until the report is clean. Each round narrows the gap.
4. **Run `/doc-to-scenarios`**, then **review**.

This path is **iterative**: `evaluate-doc` acts as a feedback loop that guides you toward a testable document.

---

## How the paths compare

| | Path A | Path B | Path C | Path D |
|---|---|---|---|---|
| **Starting from** | Unknown site | Known flow | Nothing | Existing docs |
| **Who writes the document** | Claude (autonomous) | You (in a browser) | Your LLM | A human (already written) |
| **Key tool** | /crawl-site | /record-scenario | DOC_GUIDE.md | evaluate-doc |
| **Feedback loop** | None | None | Minimal | Iterative |
| **Output partition** | `crawl/` | `record/` | `convert/` | `convert/` |
| **Fastest to reviewed scenario** | Medium | Fastest | Medium | Slow (iteration) |

---

## Review against the live site

Once a scenario exists in any partition, audit it against the running site before generating tests.

```
/review-scenario checkout-flow
/review-scenario record         # review every scenario in the record partition
/review-scenario                # review every scenario across all partitions
```

1. Opens the URL via `playwright-cli`.
2. Walks each test case and records observations.
3. Tags findings by severity: broken, vague, missing-coverage, style.
4. Launches parallel subagents to rewrite the scenario with fixes.
5. Reports a summary table of what changed.

!!! tip
    Always review before generating tests. Scenarios written from documents or recordings often contain claims that don't match the live site.

---

## Generate tests

With reviewed scenarios in place, `/scenario-to-tests` produces executable tests.

```
/scenario-to-tests checkout-flow
/scenario-to-tests record       # generate for every scenario in the record partition
/scenario-to-tests              # generate across all partitions
```

1. Resolves config (test directory, language, framework, base class).
2. Explores the live site to observe actual behavior.
3. Generates one test file per scenario at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`.
4. Runs the tests and fixes failures.

Use `--dry-run` to write the files without running them.

---

## Monitor status

`/scenario-status` is the dashboard for the whole pipeline — review dates, test file existence, pass/fail, coverage gaps — grouped by partition.

```
/scenario-status
```

Run it any time you want a single view of what's reviewed, what's tested, what's stale, and what's missing.

---

## Fixture workflow

When scenarios share test data (personas, addresses, payment details):

1. **Create a fixture:** `/generate-fixture interactive --name=returning-customer`
2. **Reference it in scenarios:** `**Fixture:** fixtures/returning-customer`
3. **Branch for alternate paths:** `**Branch:** shipping.country = CA`

Fixtures are JSON files under `<scenario_dir>/fixtures/`. See the `fixture-format` skill for the schema.

---

## Quick reference

| If you... | Path |
|-----------|------|
| Don't know what flows exist | **A** — `/crawl-site` |
| Know the flow and want to record it | **B** — `/record-scenario` |
| Are writing docs from scratch with an LLM | **C** — give the LLM `DOC_GUIDE.md`, then `/doc-to-scenarios` |
| Have an existing document that might not be testable | **D** — `evaluate-doc` → fix → `/doc-to-scenarios` |
