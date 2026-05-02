---
icon: lucide/graduation-cap
---

# Tutorial

A walkthrough from installation to your first generated tests. Pick one of three quick-start paths to write a scenario into the appropriate partition (`record/`, `crawl/`, or `convert/`), then run the shared pipeline to review, generate, and monitor. (See [Workflow](workflow.md) for a fourth path: authoring documents from scratch with an LLM.)

## Setup

1. Install Git, Docker, and Claude.
2. Clone a template repo in your language of choice:
    - kotlin template link
    - python template link
    - typescript template link
3. Start the docker image:
    ```
    docker run imageName
    ```
4. Start a Claude Code session:
    ```
    claude
    ```
5. Install the plugin:
    ```
    /plugin marketplace add mattbobambrose/playwright-scenarios
    /plugin install playwright-scenarios@playwright-scenarios
    ```

---

## Crawl a site

You don't know what flows exist and want Claude to discover them autonomously.

```
/crawl-site http://localhost:8080
```

Claude navigates the site, identifies user flows, and writes scenarios to `<scenario_dir>/crawl/` with minimal input.

---

## Record a flow

You know the flow you want to test and want to capture it by driving a browser.

```
/record-scenario
```

A Chromium window opens with the Playwright Inspector. Drive the browser, mark assertions, and Claude converts the recording into a scenario markdown file at `<scenario_dir>/record/<name>.md`.

---

## Convert a document

You already have a written description of what to test — test plan, requirements doc, user stories, meeting notes.

```
/doc-to-scenarios <docFileName>
```

Claude evaluates the document and converts it into one or more scenarios under `<scenario_dir>/convert/` with tag mapping.

---

## Shared pipeline

Every path writes scenarios directly into a partition under `<scenario_dir>/`. From there:

1. **(Optional) Hand-edit or delete in place.** The scenario in its partition is the canonical artifact — there's no draft / promote step. Open the file in your editor if you want to refine it, or delete any you don't care about.
2. **`/review-scenario`** — audit each scenario against the live site and apply improvements to the markdown. Pass a partition name (`record`, `crawl`, or `convert`) to scope the review, or run with no args to review everything.
3. **`/scenario-to-tests`** — generate tests in your configured language and framework. Output is partitioned by command and by scenario: `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`.
4. **`/scenario-status`** — health dashboard for review dates, test status, pass/fail, and coverage, grouped by partition.
