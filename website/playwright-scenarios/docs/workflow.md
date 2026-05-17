---
icon: lucide/git-branch
---

# Workflow

The plugin's job is to take you from *"I want to test this website"* to *executable tests*. The pipeline has three stages — **author → review → generate** — plus a status command for monitoring.

Every creation command writes its scenario directly to its own **source folder** — `<scenario_dir>/crawl/`, `<scenario_dir>/record/`, or `<scenario_dir>/convert/`. The scenario is the canonical artifact; if you want to hand-edit or delete some before review, you do so in place.

The question is: **how do you get to a scenario in the first place?** Four paths, depending on where you're starting from.

---

## Path A: Crawl a site autonomously

You don't know what flows exist and want Claude to discover them.

```
/crawl-site https://mysite.com focus on the checkout flow
/crawl-site https://mysite.com shallow overview
/crawl-site https://mysite.com
```

1. Give the starting URL and an optional description of what to focus on. The description can be goal-oriented ("focus on checkout"), intensity-oriented ("deeply explore every path"), or a hybrid ("broad overview but prioritize account management flows").
2. Goes to the starting URL, inventories links and interactive elements, interprets your description, and groups and ranks flows, prioritizing those matching your description.
3. Shows you the interpreted crawl plan — scope, depth, and which flows it intends to walk — for approval before proceeding.
4. Walks each approved flow (read-only — never fills forms).
5. Writes scenarios to `<scenario_dir>/crawl/` and saves crawl metadata for `/scenario-status`.

Best for bootstrapping coverage. The description lets you steer toward specific areas without manual flag-tuning. Delete any crawl-emitted scenarios you don't want before running `/review-scenario`.

---

## Path B: Record a flow in a browser

You know the flow and want to capture it by demonstrating it.

```
/record-scenario https://mysite.com flow-name
/record-scenario https://mysite.com
```

1. Give the starting URL and an optional flow name (used in the scenario title and file name).
2. Opens Playwright codegen — you drive the browser from the starting URL.
3. Converts the recording into `<scenario_dir>/record/<flow-name>.md`.
4. Hand-edit as needed, then run `/review-scenario`.

Best for interactive flows (form fills, logins) where watching the flow is faster than writing it.

---

## Path C: Generate documents with an LLM

You're starting from scratch and using an LLM (ChatGPT, Claude, Gemini, etc.) to write your test documents.

```
/doc-to-scenarios myexample.md
```

1. Paste [TEST_DOC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md) into your LLM's context — system prompt, custom GPT instructions, or the start of a conversation. This teaches the LLM the rules *before* it writes anything.
2. Ask the LLM to write your document. Because it already knows what the test framework can handle, what format to use, and what pitfalls to avoid, the output should be clean on the first pass.
3. Run `/doc-to-scenarios` to convert. The evaluation step will mostly confirm the document is already well-formed. Output lands in `<scenario_dir>/convert/`.
4. Run `/review-scenario` to verify against the live site (optionally hand-edit the convert-folder scenarios first).

This path is **front-loaded**: you invest in the LLM's instructions once, and the output needs little to no revision. The `evaluate-doc` step becomes a rubber stamp rather than a feedback loop.

---

## Path D: Migrate existing documents

You already have documents that weren't written with this framework in mind.

```
Evaluate mytestdoc.md
```

`evaluate-doc` is a skill, not a slash command — you start it by asking Claude in plain language, as above.

1. Run `evaluate-doc` against your document. It classifies each test case as direct, needs changes, extended tag, or out of scope.
2. Fix issues in place. The evaluation report tells you exactly what to change — vague selectors, missing iframe notes, display text without DOM identifiers, untestable assertions.
3. Re-evaluate until the report is clean. Each round narrows the gap.
4. Run `/doc-to-scenarios`, then review.

This path is **iterative**: `evaluate-doc` acts as a feedback loop that guides you toward a testable document.

---

## How the paths compare

| | Path A | Path B | Path C | Path D |
|---|---|---|---|---|
| **Starting from** | Unknown site | Known flow | Nothing | Existing docs |
| **Who writes the document** | Claude (autonomous) | You (in a browser) | Your LLM | A human (already written) |
| **Key tool** | /crawl-site | /record-scenario | TEST_DOC_GUIDE.md | evaluate-doc |
| **Feedback loop** | None | None | Minimal | Iterative |
| **Output folder** | `crawl/` | `record/` | `convert/` | `convert/` |
| **Fastest to reviewed scenario** | Medium | Fastest | Medium | Slow (iteration) |

---

## Review against the live site

Once a scenario exists in any folder, audit it against the running site before generating tests.

```
/review-scenario checkout-flow
/review-scenario record         # review every scenario in the record folder
/review-scenario                # review every scenario across all folders
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
/scenario-to-tests record       # generate for every scenario in the record folder
/scenario-to-tests              # generate across all folders
```

1. Resolves config (test directory, language, framework, base class).
2. Explores the live site to observe actual behavior.
3. Generates one test file per scenario at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`.
4. Runs the tests and fixes failures.

Use `--dry-run` to write the files without running them.

---

## Monitor status

`/scenario-status` is the dashboard for the whole pipeline — review dates, test file existence, pass/fail, coverage gaps — grouped by folder.

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
| Are writing docs from scratch with an LLM | **C** — give the LLM `TEST_DOC_GUIDE.md`, then `/doc-to-scenarios` |
| Have an existing document that might not be testable | **D** — `evaluate-doc` → fix → `/doc-to-scenarios` |
