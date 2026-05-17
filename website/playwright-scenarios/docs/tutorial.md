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

**Bring your own site.** This tutorial points at the bundled bookstore demo on `http://localhost:8080` so every step has a concrete target. Anything tied to the demo is swappable: the Docker container, the start URL, the doc path, the recorded flow. Each step calls out what to substitute under a **For your project:** note. If you already have a dev or staging server you want to test, you can replace `http://localhost:8080` with its URL throughout and skip the Docker container in Step 1.

---

## Step 1: Setup

Do this once before working through any of the authoring sections. Each command is prefaced with **Terminal:**, **Browser:**, or **Claude Code:** to indicate where to run it. (Steps 7 and 8 run inside the Claude Code session you started in step 6.)

1. Install Git, Docker, Node.js, and Claude. Then install `playwright-cli` (used by `/crawl-site`, `/review-scenario`, and `/scenario-to-tests` for live-site exploration):

    **Terminal:**

    ```
    npm install -g @playwright/cli@latest
    ```

2. Start the Bookshelf app in a Docker container. It serves a small bookstore at `http://localhost:8080`:

    **Terminal:**

    ```
    docker run --rm -p 8080:8080 mattbobambrose/playwright-scenario-playground
    ```

    **For your project:** Skip this step if you already have a dev or staging server you want to test. Use that URL anywhere this tutorial says `http://localhost:8080`.

3. **Browser:** Open the [Playwright Scenarios Kotlin template](https://github.com/mattbobambrose/playwright-scenarios-kotlin-template) in GitHub and click **Use this template → Create a new repository** to spin up your own copy. Kotlin is the supported language today, but Python and TypeScript are in the works.

4. Clone the new repo locally and `cd` into it. You'll find the URL under **Code → Clone → HTTPS**:

    **Terminal:**

    ```
    git clone <your-new-repo-url>
    cd <your-new-repo-name>
    ```

5. Install the Playwright browsers (one-time, ~200 MB):

    **Terminal:**

    ```
    ./gradlew installPlaywrightBrowsers
    ```

6. Start a Claude Code session at the repo root with permission prompts disabled:

    **Terminal:**

    ```
    claude --dangerously-skip-permissions
    ```

    The plugin commands kick off many tool calls per invocation (file reads, file writes, `playwright-cli` launches, Gradle runs). The `--dangerously-skip-permissions` flag bypasses every prompt for the session — safe to use in a disposable / sandboxed checkout like the template repo you just cloned.

    **Best practice:** Run Claude on high effort. The plugin's commands are long, multi-step tasks — a site crawl, a live-site scenario review, a generate-and-fix-tests loop — and they go markedly better with deeper reasoning: wider crawl coverage, sharper reviews, and fewer failing tests to chase down.

7. Install the plugin:

    **Claude Code:**

    ```
    /plugin marketplace add mattbobambrose/playwright-scenarios
    /plugin install playwright-scenarios@playwright-scenarios
    ```

    When prompted for the scope of the plugin's install, choose **Install for user (user scope)**

8. Create a base test class so generated tests have something to extend:

    **Claude Code:**

    ```
    /create-base-test
    ```

    This is your first plugin command, so two prompts fire in sequence: first the config bootstrap (`scenario_dir`, `test_dir`, `test_language`, `test_framework`), then three customizations (whether the dev server has a `POST /reset` endpoint, lifecycle scope, browser). Accept the defaults — **except the `POST /reset` endpoint prompt: answer Yes**. The bookstore demo exposes a reset endpoint, so `BasePageTest` can reset its state between tests; that prompt otherwise defaults to No, since most real dev servers don't have one. Claude writes `BasePageTest.kt` next to your scenarios package and persists `base_test_class` in the config.

    **For your project:** The defaults match the kotlin template's layout. If you're applying the plugin to your own project, see the [Configuration table in the README](https://github.com/mattbobambrose/playwright-scenarios#configuration) for what each field controls and override the prompts as needed. You can re-prompt later with `/playwright-scenarios-config`.

---

## Step 2: Crawl a site → tests

The first authoring path is the most hands-off: tell `/crawl-site` where to start and let Claude discover user flows on its own.

### Run the crawl

**Claude Code:**

```
/crawl-site http://localhost:8080
```

Claude inventories the start page, ranks candidate flows, walks each (read-only — no form submits), and writes one scenario per flow to `<scenario_dir>/crawl/`. Respond to any prompts Claude shows along the way — accepting the recommended option each time is fine for a first run.

**For your project:** Replace `http://localhost:8080` with any URL Claude can reach — your dev server, a staging environment, a public site. You can also append a natural-language description to focus the crawl, e.g.:

```
/crawl-site https://mysite.com focus on the checkout flow
```

### Review the scenarios

**Claude Code:**

```
/review-scenario crawl
```

The `crawl` argument scopes the review to scenarios in the crawl folder. Claude opens each one against the live site, verifies the claims, tightens vague assertions, and rewrites the markdown in place. You'll see a summary table of what changed.

### Generate tests

**Claude Code:**

```
/scenario-to-tests crawl
```

For each reviewed scenario in `<scenario_dir>/crawl/`, Claude:

- generates a test file at `<test_dir>/crawl/<scenario-name>/<ClassName>.kt`
- runs the suite
- fixes failures

You now have your first batch of executable tests.

### Run tests

**Terminal:**

```
make clean test
```

Claude already ran the suite while generating — run it yourself and watch it go green.

---

## Step 3: Record a flow → tests

For interactive flows (logins, form fills, multi-step purchases) it's faster to *demonstrate* the flow than to describe it.

### Record

**Claude Code:**

```
/record-scenario
```

Claude prompts you for a Start URL — paste `http://localhost:8080`. A Chromium window then opens with the Playwright Inspector pointed at that URL. Drive the browser through the flow you want to test — click links, fill forms, mark assertions using the Inspector's "Assert visibility / text / value" toolbar buttons. Close the browser when done.

You can also pass the Start URL as an argument to skip the prompt:

```
/record-scenario http://localhost:8080
```

**For your project:** Drive the browser to whichever flow you actually care about — login, checkout, a multi-step form, anything you'd test by hand. The recorded flow is whatever you do in the window; there's no fixed script.

Claude converts the recorded actions into a scenario markdown file at `<scenario_dir>/record/<name>.md`. You'll be prompted to confirm the inferred name if you didn't supply one.

### Review and generate

**Claude Code:**

```
/review-scenario record
/scenario-to-tests record
```

Same shape as Step 2 — scoped this time to the `record` folder. The new tests land at `<test_dir>/record/<scenario-name>/<ClassName>.kt`, alongside the crawl tests from earlier.

### Run tests

**Terminal:**

```
make clean test
```

Claude already ran the suite while generating — run it yourself and watch it go green.

---

## Step 4: Generate docs with an LLM → tests

The third path starts from a written description. You can hand it to any LLM (ChatGPT, Claude, Gemini), have it produce a test document in the plugin's expected shape, and convert that document into scenarios.

### Generate a document

**Browser (external LLM):** Paste [`TEST_DOC_GUIDE.md`](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md) into your LLM's context — system prompt, custom GPT instructions, or the start of a conversation. This teaches the LLM the format, the available tags, and the pitfalls to avoid *before* it writes anything.

**Tip:** Paste `TEST_DOC_GUIDE.md` as a **system prompt or custom instructions** rather than a mid-conversation message — system-prompt placement anchors the framing most reliably and the LLM is more likely to apply the rules than to critique them. If you do paste mid-conversation, include your request in the same message (e.g. "here are the rules, now draft a test document for the checkout flow") instead of pasting the guide alone and waiting. If the LLM still responds with suggestions for improving the guide instead of drafting a document, reply once with "Apply the rules; don't critique them. Draft a test document for [your flow]." and it will correct course. The guide's "How to use this guide" section anchors this, but LLM behavior is probabilistic — these tips compound.

Then ask it to draft a document covering the flows you care about. Save the output to a file in your repo, e.g. `docs/checkout-tests.md`.

### Convert to scenarios

**Claude Code:**

```
/doc-to-scenarios docs/checkout-tests.md
```

**For your project:** `docs/checkout-tests.md` is illustrative — pass any path to your own document. Existing test plans, requirements docs, meeting notes, and acceptance criteria all work as input.

Claude runs `evaluate-doc` first (a sanity check that the doc is well-formed for conversion), pauses for your approval, then writes one scenario per flow to `<scenario_dir>/convert/`.

### Review and generate

**Claude Code:**

```
/review-scenario convert
/scenario-to-tests convert
```

The third batch of tests lands at `<test_dir>/convert/<scenario-name>/<ClassName>.kt`.

### Run tests

**Terminal:**

```
make clean test
```

Claude already ran the suite while generating — run it yourself and watch it go green.

---

## Step 5: Check the dashboard

**Claude Code:**

```
/scenario-status
```

You'll see all three batches grouped by folder — review dates, test file existence, pass/fail, plus coverage signals (crawl depth reached, flow types covered, conversion rate). Run this any time you want a single view of what's reviewed, what's tested, what's stale, and what's missing.

---

## Where to go next

- **[Workflow](workflow.md)** — the conceptual map of all four paths to a reviewed scenario, including a fourth path (migrating existing docs that weren't written for this framework) that this tutorial skips.
- **[Commands & Skills](commands.md)** — full reference for every command and skill, including flags and prerequisites.
- **[FAQ](faq.md)** — conceptual and scope questions ("Do I have to use the bookstore demo?", "What if my project isn't Kotlin?", "Why do I need Node.js?").
- **[Writing Test Docs](writing-test-docs.md)** — guidance on writing or refining test documents that convert cleanly via `/doc-to-scenarios`.
- **[Troubleshooting](troubleshooting.md)** — Symptom → Cause → Fix entries for the failures you're most likely to hit at setup and runtime.
