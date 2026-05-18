---
icon: lucide/graduation-cap
---

# Tutorial

A linear walkthrough from a fresh machine to a growing test suite. We'll set up the environment once, then exercise each of the three scenario authoring paths in turn — **crawl**, **record**, and **doc-driven** — running the full review/generate pipeline after each so you end up with three batches of scenarios and tests.

**Bring your own site.** This tutorial points at the bundled bookstore demo on `http://localhost:8080` so every step has a concrete target. Anything tied to the demo is swappable: the Docker container, the start URL, the doc path, the recorded flow. Each step calls out what to substitute under a **For your project:** note. If you already have a dev or staging server you want to test, you can replace `http://localhost:8080` with its URL throughout and skip the Docker container in Step 1.

---

## Step 1: Setup

Do this once before working through any of the authoring sections. Each command is prefaced with **Terminal:**, or **Claude Code:** to indicate where to run it. (Steps 7 and 8 run inside the Claude Code session you started in step 6.)

1. Install Git, Docker, Node.js, and Claude.

2. Install `playwright-cli` (used by `/crawl-site`, `/review-scenario`, and `/scenario-to-tests` for live-site exploration):

    **Terminal:**

    ```
    npm install -g @playwright/cli@latest
    ```

3. Start the Bookshelf app in a Docker container. It serves a small bookstore at `http://localhost:8080`:

    **Terminal:**

    ```
    docker run --rm -p 8080:8080 mattbobambrose/playwright-scenario-playground
    ```

    **For your project:** Skip this step if you already have a dev or staging server you want to test. Use that URL anywhere this tutorial says `http://localhost:8080`.

4. Open the [Playwright Scenarios Kotlin template](https://github.com/mattbobambrose/playwright-scenarios-kotlin-template) and click **Use this template → Create a new repository** to create your own version of the repo. Kotlin is the supported language today, but Python and TypeScript are in the works.

5. Clone the repo you created from the template locally and `cd` into it. You'll find the URL for the new repo by clicking on the **Code** button:

    **Terminal:**

    ```
    git clone <your-new-repo-url>
    cd <your-new-repo-name>
    ```

6. Install the Playwright browsers (one-time, ~200 MB):

    **Terminal:**

    ```
    ./gradlew installPlaywrightBrowsers
    ```

7. Start a Claude Code session at the repo root with permission prompts disabled:

    **Terminal:**

    ```
    claude --dangerously-skip-permissions
    ```

    The plugin commands kick off many tool calls per invocation (file reads, file writes, `playwright-cli` launches, Gradle runs). The `--dangerously-skip-permissions` flag bypasses the prompts for the session.

    **Best practice:** Run Claude on high effort. The plugin's commands are long, multi-step tasks — a site crawl, a live-site scenario review, a generate-and-fix-tests loop — and they go markedly better with deeper reasoning: wider crawl coverage, sharper reviews, and fewer failing tests to chase down.

8. Install the `playwright-scenarios` plugin:

    **Claude Code:**

    ```
    /plugin marketplace add mattbobambrose/playwright-scenarios
    /plugin install playwright-scenarios@playwright-scenarios
    ```

    When prompted for the scope of the plugin's install, choose **Install for user (user scope)**

9. Create a base test class to act as a parent class for generated tests:

    **Claude Code:**

    ```
    /create-base-test
    ```

    This command writes `BasePageTest.kt` next to your scenarios package and persists `base_test_class` in the config.

    This is your first plugin command. Two prompts will fire in sequence: first the config bootstrap (`scenario_dir`, `test_dir`, `test_language`, `test_framework`), then three customizations: the **reset** endpoint question (whether the dev server exposes a `POST /reset` endpoint), lifecycle scope, and browser. When prompted for preferences, accept the defaults, with the exception of the **reset** endpoint question, where you should answer `Yes`. This is because the bookstore demo exposes a reset endpoint, so `BasePageTest` can reset its state between tests.

    **For your project:** The defaults match the kotlin template's layout. If you're applying the plugin to your own project, see the [Configuration table in the README](https://github.com/mattbobambrose/playwright-scenarios#configuration) for what each field controls and override the prompts as needed. You can re-prompt later with `/playwright-scenarios-config`.

---

## Step 2: Crawl a site → tests

The `/crawl-site` command lets Claude discover user flows on its own.

### Run the crawl

**Claude Code:**

```
/crawl-site http://localhost:8080
```

`/crawl-site` inventories the start page, ranks candidate flows, walks each (read-only — no form submits), and writes one scenario per flow to `src/test/scenarios/crawl/`. Respond to any prompts Claude shows along the way — accepting the recommended option each time is fine for a first run.

You'll find the generated scenarios at `src/test/scenarios/crawl`. Open one and skim it — this human-readable markdown is the scenario format the rest of the pipeline reviews and turns into tests.

Additionally, you can append a natural-language description to focus the crawl, e.g.:

```
/crawl-site http://localhost:8080 focus on the checkout flow
/crawl-site http://localhost:8080 cover the sign-up and login flows
/crawl-site http://localhost:8080 do a thorough crawl of the dashboard
```

**For your project:** Replace `http://localhost:8080` with any URL Claude can reach — your dev server, a staging environment, a public site.

### Review the scenarios

**Claude Code:**

```
/review-scenario crawl
```

The `crawl` argument scopes the review to scenarios in the crawl folder. You can provide `/review-scenario` with either the name of a folder (`crawl`, `record`, `convert`), the name of a file, or no name. Claude opens each one against the live site, verifies the claims, tightens vague assertions, and rewrites the markdown in place. You'll see a summary table of what changed.

### Generate tests

**Claude Code:**

```
/scenario-to-tests crawl
```

For each reviewed scenario in `src/test/scenarios/crawl/`, Claude will:

- generate a test file at `src/test/kotlin/com/bookshelf/scenarios/crawl/`
- run the suite
- fix failures

You now have your first batch of tests in `src/test/kotlin/com/bookshelf/scenarios/crawl/`.

### Run tests

**Terminal:**

```
make clean tests
```

Claude already ran the suite while generating, but this is how you can run it manually.

---

## Step 3: Record a flow → tests

For interactive flows (logins, form fills, multi-step purchases) it's easier to *demonstrate* the flow than to describe it.

### Record a scenario

**Claude Code:**

```
/record-scenario http://localhost:8080
```

A Chromium window will open with the Playwright Inspector pointed at the given URL. Drive the browser through the flow you want to test — click links, fill forms, mark assertions using the Inspector's "Assert visibility / text / value" toolbar buttons. Close the browser when done.

Claude converts the recorded actions into a scenario markdown file at `src/test/scenarios/record/<name>.md`. You'll be prompted to confirm the inferred name if you didn't supply one.

**For your project:** Drive the browser to whichever flow you actually care about — login, checkout, a multi-step form, anything you'd test by hand. The recorded flow is whatever you do in the window; there's no fixed script.

### Review the scenario

**Claude Code:**

```
/review-scenario record
```

Same as Step 2, scoped to the `record` folder — Claude verifies each scenario against the live site and rewrites the markdown in place.

### Generate tests

**Claude Code:**

```
/scenario-to-tests record
```

The new tests will be at `src/test/kotlin/com/bookshelf/scenarios/record/`, alongside the crawl tests from earlier.

### Run tests

**Terminal:**

```
make clean tests
```

---

## Step 4: Convert a doc → tests

The third path starts from a written test document — a test plan, requirements, a user story, acceptance criteria — and converts it into scenarios.

### The sample documents

Two example test documents are in `src/test/docs/`, both describing the bookstore demo's checkout flow from different angles:

- **`checkout-user-story.md`** — the flow framed as a user story with acceptance criteria.
- **`checkout-test-spec.md`** — the checkout page covered exhaustively: every element that should render, every interaction a user can perform, and the expected outcome of each.

Both documents were written according to the rules in [`TEST_DOC_GUIDE.md`](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md).

**For your project:** To convert your own flows, write a document that follows the rules in [`TEST_DOC_GUIDE.md`](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/TEST_DOC_GUIDE.md). Test documents can be written manually or with the assistance of an LLM (ChatGPT, Claude, Gemini): give the LLM a link to that guide plus a description of what to test. Existing test plans, requirements docs, meeting notes, and acceptance criteria also work directly as input. See [Writing Test Docs](writing-test-docs.md) for full guidance.

### Convert test doc to scenarios

Convert the user story document with:

**Claude Code:**

```
/doc-to-scenarios src/test/docs/checkout-user-story.md
```

Claude pauses for your approval, then writes one scenario per flow.

Run the same command for the test spec:

```
/doc-to-scenarios src/test/docs/checkout-test-spec.md
```

Both of these will write their scenarios to `src/test/scenarios/convert/`.

Because both sample documents include a **Test data** table, the generated scenarios reference a *fixture* — a small JSON file of shared test data (the customer persona and form inputs) that the generated tests read from instead of hard-coding values in each test. When Claude offers to create it with `/generate-fixture`, accept it.

### Review the scenarios

**Claude Code:**

```
/review-scenario convert
```

Same as Step 2, scoped to the `convert` folder — Claude verifies each scenario against the live site and rewrites the markdown in place.

### Generate tests

**Claude Code:**

```
/scenario-to-tests convert
```

You'll find the resulting tests at `src/test/kotlin/com/bookshelf/scenarios/convert/`.

### Run tests

**Terminal:**

```
make clean tests
```

---

## Step 5: Check the dashboard

**Claude Code:**

```
/scenario-status
```

You'll see all three test batches grouped by folder — review dates, test file existence, pass/fail, plus coverage signals (crawl depth reached, flow types covered, conversion rate). Run this when you want a single view of what's reviewed, tested, stale, and missing.

---

## Where to go next

- **[Workflow](workflow.md)** — the conceptual map of all four paths to a reviewed scenario, including a fourth path (migrating existing docs that weren't written for this framework) that this tutorial skips.
- **[Commands & Skills](commands.md)** — full reference for every command and skill, including flags and prerequisites.
- **[FAQ](faq.md)** — conceptual and scope questions ("Do I have to use the bookstore demo?", "What if my project isn't Kotlin?", "Why do I need Node.js?").
- **[Writing Test Docs](writing-test-docs.md)** — guidance on writing or refining test documents that convert cleanly via `/doc-to-scenarios`.
- **[Troubleshooting](troubleshooting.md)** — Symptom → Cause → Fix entries for the failures you're most likely to hit at setup and runtime.
