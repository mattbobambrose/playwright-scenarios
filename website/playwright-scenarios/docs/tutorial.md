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

> **Bring your own site.** This tutorial points at the bundled bookshelf demo on `http://localhost:8080` so every step has a concrete target. Anything tied to the demo is swappable: the Docker container, the start URL, the doc path, the recorded flow. Each step calls out what to substitute under a **Customize:** note. If you already have a dev or staging server you want to test, you can replace `http://localhost:8080` with its URL throughout and skip the Docker container in Step 1.

---

## Step 1: Setup

Do this once before working through any of the authoring sections.

1. Install Git, Docker, Node.js, and Claude. Then install the `playwright-cli` prerequisite (used by `/review-scenario`, `/scenario-to-tests`, and `/crawl-site` for live-site exploration):
    ```
    npm install -g @playwright/cli@latest
    ```
2. Use the [Kotlin template repo](https://github.com/mattbobambrose/playwright-scenarios-kotlin-template) as the starting point. Click **Use this template → Create a new repository** on the GitHub page to get your own copy, then clone it locally. (You can also `git clone` the template directly if you don't want a fresh repo of your own.) Kotlin is the supported stack today — Python and TypeScript templates are planned but not yet available.
3. Start the demo site in a Docker container. It serves a small bookshelf app at `http://localhost:8080`:
    ```
    docker run --rm -p 8080:8080 mattbobambrose/playwright-scenario-playground
    ```
    > **Customize:** Skip this step if you already have a dev or staging server you want to test. Use that URL anywhere this tutorial says `http://localhost:8080`.
4. Download the Playwright browsers (one-time, ~200 MB):
    ```
    ./gradlew installPlaywrightBrowsers
    ```
5. Start a Claude Code session at the repo root:
    ```
    claude
    ```
    Alternatively, run with permission prompts disabled:
    ```
    claude --dangerously-skip-permissions
    ```
    The plugin commands kick off many tool calls per invocation (file reads, file writes, `playwright-cli` launches, Gradle runs). With the default `claude`, you'll click **Approve** for each one. The `--dangerously-skip-permissions` flag bypasses every prompt for the session — use it only in a disposable / sandboxed checkout like the template repo you just cloned.
6. Install the plugin:
    ```
    /plugin marketplace add mattbobambrose/playwright-scenarios
    /plugin install playwright-scenarios@playwright-scenarios
    ```
7. Scaffold a base test class so generated tests have something to extend:
    ```
    /scaffold-base-test
    ```
    This is your first plugin command, so two prompts fire in sequence: first the config bootstrap (`scenario_dir`, `test_dir`, `test_language`, `test_framework`), then three scaffold customizations (whether the dev server has a `POST /reset` endpoint, lifecycle scope, browser). Accept the defaults at every prompt to follow along with the tutorial. Claude writes `BasePageTest.kt` next to your scenarios package and persists `base_test_class` in the config.

    > **Customize:** The defaults match the kotlin template's layout. If you're applying the plugin to your own project, see the [Configuration table in the README](https://github.com/mattbobambrose/playwright-scenarios#configuration) for what each field controls and override the prompts as needed. You can re-prompt later with `/playwright-scenarios-config`.

---

## Step 2: Crawl a site → tests

The first authoring path is the most hands-off: tell `/crawl-site` where to start and let Claude discover user flows on its own.

### Run the crawl

```
/crawl-site http://localhost:8080
```

Claude inventories the start page, ranks candidate flows, walks each (read-only — no form submits), and writes one scenario per flow to `<scenario_dir>/crawl/`. Respond to any prompts Claude shows along the way — accepting the recommended option each time is fine for a first run.

> **Customize:** Replace `http://localhost:8080` with any URL Claude can reach — your dev server, a staging environment, a public site. You can also append a natural-language description to focus the crawl, e.g. `/crawl-site https://example.com focus on the checkout flow`.

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

> **Customize:** Drive the browser to whichever flow you actually care about — login, checkout, a multi-step form, anything you'd test by hand. The recorded flow is whatever you do in the window; there's no fixed script.

Claude converts the recorded actions into a scenario markdown file at `<scenario_dir>/record/<name>.md`. You'll be prompted to confirm the inferred name if you didn't supply one.

### Review and generate

```
/review-scenario record
/scenario-to-tests record
```

Same shape as Step 2 — scoped this time to the `record` partition. The new tests land at `<test_dir>/record/<scenario-name>/<ClassName>.kt`, alongside the crawl tests from earlier.

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

> **Customize:** `docs/checkout-tests.md` is illustrative — pass any path to your own document. Existing test plans, requirements docs, meeting notes, and acceptance criteria all work as input.

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
