---
icon: lucide/rocket
---

# playwright-scenarios

Claude Code plugin for scenario-driven Playwright testing — crawl, record, evaluate, convert, review, and generate tests from human-readable scenario markdown.

## What is it?

[playwright-scenarios](https://github.com/mattbobambrose/playwright-scenarios) is a Claude Code plugin that lets you author browser-driven test scenarios as flat markdown files, audit those scenarios against the live site, and translate them into test classes. The plugin ships 9 commands, 6 skills, and 13 extended tags.

[playwright-scenarios](https://github.com/mattbobambrose/playwright-scenarios) works with any project that supports Playwright for browser automation. The default test generation stack is Kotlin + Kotest StringSpec + Playwright-for-Java, with support for TypeScript and Python planned.

## How it works

``` mermaid
graph TD
    A[Your website]
    A -->|"/crawl-site"| B[Scenario]
    A -->|"/record-scenario"| B
    A -->|"/doc-to-scenarios"| B
    B -->|"/review-scenario"| C[Reviewed<br/>scenario]
    C -->|"/scenario-to-tests"| D[Test suite]
```

Three quick-start authoring paths converge on `/scenario-to-tests`. See the [Workflow](workflow.md) page for a fourth path (LLM-authored documents, which routes through `/doc-to-scenarios`) and a side-by-side comparison.

A **scenario** is an LLM-optimized markdown representation of the flow you want to test — readable by humans, mechanically processable by Claude. You produce one by recording a browser session, crawling the site, or converting an existing document — each writes to its own folder (`scenarios/crawl/`, `scenarios/record/`, `scenarios/convert/`). Hand-edit or delete in place if you want; then `/review-scenario` audits against the live site, and `/scenario-to-tests` turns the reviewed scenarios into a runnable test suite at `<test_dir>/<command>/<scenario-name>/`.

## Learn more

<div class="grid cards" markdown>

-   :lucide-graduation-cap: **[Tutorial](tutorial.md)**

    ---

    Step-by-step walkthrough from installation to generated tests.

-   :lucide-book-open: **[Terminology](terminology.md)**

    ---

    Definitions for scenario, test case, source folder, fixture, tag, and more.

-   :lucide-git-branch: **[Workflow](workflow.md)**

    ---

    The full pipeline from document to generated tests, with decision points.

-   :lucide-check-circle: **[Capabilities](capabilities.md)**

    ---

    What the plugin can test, what it can't, and where gaps live instead.

-   :lucide-pencil: **[Writing Test Docs](writing-test-docs.md)**

    ---

    Guidance for writing test documents that convert cleanly into scenarios.

</div>
