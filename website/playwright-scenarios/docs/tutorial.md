---
icon: lucide/graduation-cap
---

# Tutorial

A linear walkthrough from a fresh machine to a growing test suite. We'll set up the environment once, then exercise each of the three authoring paths in turn — **crawl**, **record**, and **doc-driven** — running the full review/generate pipeline after each so you end up with three batches of executable tests.

By the end you'll have:

- Tests under `<test_dir>/crawl/` from a `/crawl-site` run.
- Tests under `<test_dir>/record/` from a `/record-scenario` run.
- Tests under `<test_dir>/convert/` from a `/doc-to-scenarios` run.
- A health dashboard view via `/scenario-status` that ties them all together.

---

## Step 1: Setup

Do this once before working through any of the authoring sections.

1. Install Git, Docker, and Claude.
2. Clone the Kotlin template repo *(link to be filled in)*. This is the supported stack today — Python and TypeScript templates are planned but not yet available.
3. Start the docker image (it bundles a small demo site at `http://localhost:8080`):
    ```
    docker run imageName
    ```
4. Start a Claude Code session at the repo root:
    ```
    claude
    ```
5. Install the plugin:
    ```
    /plugin marketplace add mattbobambrose/playwright-scenarios
    /plugin install playwright-scenarios@playwright-scenarios
    ```
6. The first time you run any plugin command, you'll be prompted for `scenario_dir`, `test_dir`, `test_language`, and `test_framework`. Accept the defaults to follow along with this tutorial.

---

## Step 2: Crawl a site → tests

The first authoring path is the most hands-off: tell `/crawl-site` where to start and let Claude discover user flows on its own.

### Run the crawl

```
/crawl-site http://localhost:8080
```

A bare URL triggers an interactive menu. Pick **Structural overview** for this run. Claude inventories the start page, ranks candidate flows, walks each (read-only — no form submits), and writes one scenario per flow to `<scenario_dir>/crawl/`.

### Review the scenarios

```
/review-scenario crawl
```

The `crawl` argument scopes the review to scenarios in the crawl partition. Claude opens each one against the live site, verifies the claims, tightens vague assertions, and rewrites the markdown in place. You'll see a summary table of what changed.

### Generate tests

```
/scenario-to-tests crawl
```

For each reviewed scenario in `<scenario_dir>/crawl/`, Claude generates a test file at `<test_dir>/crawl/<scenario-name>/<ClassName>.kt`, runs the suite, and fixes failures.

You now have your first batch of executable tests.

---

## Step 3: Record a flow → tests

For interactive flows (logins, form fills, multi-step purchases) it's faster to *demonstrate* the flow than to describe it.

### Record

```
/record-scenario
```

A Chromium window opens with the Playwright Inspector. Drive the browser through the flow you want to test — click links, fill forms, mark assertions using the Inspector's "Assert visibility / text / value" toolbar buttons. Close the browser when done.

Claude converts the recorded actions into a scenario markdown file at `<scenario_dir>/record/<name>.md`. You'll be prompted to confirm the inferred name if you didn't supply one.

### Review and generate

```
/review-scenario record
/scenario-to-tests record
```

Same shape as Section 2 — scoped this time to the `record` partition. The new tests land at `<test_dir>/record/<scenario-name>/<ClassName>.kt`, alongside the crawl tests from earlier.

---

## Step 4: Generate docs with an LLM → tests

The third path starts from a written description. You can hand it to any LLM (ChatGPT, Claude, Gemini), have it produce a test document in the plugin's expected shape, and convert that document into scenarios.

### Generate a document

Paste [`DOC_GUIDE.md`](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/DOC_GUIDE.md) into your LLM's context — system prompt, custom GPT instructions, or the start of a conversation. This teaches the LLM the format, the available tags, and the pitfalls to avoid *before* it writes anything.

Then ask it to draft a document covering the flows you care about. Save the output to a file in your repo, e.g. `docs/checkout-tests.md`.

### Convert to scenarios

```
/doc-to-scenarios docs/checkout-tests.md
```

Claude runs `evaluate-doc` first (a sanity check that the doc is well-formed for conversion), pauses for your approval, then writes one scenario per flow to `<scenario_dir>/convert/`.

### Review and generate

```
/review-scenario convert
/scenario-to-tests convert
```

The third batch of tests lands at `<test_dir>/convert/<scenario-name>/<ClassName>.kt`.

---

## Step 5: Check the dashboard

```
/scenario-status
```

You'll see all three batches grouped by partition — review dates, test file existence, pass/fail, plus coverage signals (crawl depth reached, flow types covered, conversion rate). Run this any time you want a single view of what's reviewed, what's tested, what's stale, and what's missing.

---

## Where to go next

- **[Workflow](workflow.md)** — the conceptual map of all four paths to a reviewed scenario, including a fourth path (migrating existing docs that weren't written for this framework) that this tutorial skips.
- **[Commands & Skills](commands.md)** — full reference for every command and skill, including flags and prerequisites.
- **[Writing Docs](writing-docs.md)** — guidance on writing or refining input documents that convert cleanly via `/doc-to-scenarios`.
- **[Troubleshooting](troubleshooting.md)** — Symptom → Cause → Fix entries for the failures you're most likely to hit at setup and runtime.
