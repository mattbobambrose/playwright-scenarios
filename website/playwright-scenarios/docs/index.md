---
icon: lucide/rocket
---

# playwright-scenarios

Claude Code plugin for scenario-driven Playwright testing — record, crawl, evaluate, convert, review, and generate tests from human-readable scenario markdown.

## What is it?

`playwright-scenarios` is a Claude Code plugin that lets you author browser-driven test scenarios as flat markdown files, audit those scenarios against the live site, and translate them into test classes. It ships 9 commands, 6 skills, and 13 extended tags.

The plugin works with any project that uses Playwright for browser automation. The default test generation stack is Kotlin + Kotest StringSpec + Playwright-for-Java, with other stacks planned.

## How it works

``` mermaid
graph TD
    A[User wants to<br/>test a website]
    A -->|"/crawl-site"| B[Scenario]
    A -->|"/record-scenario"| B
    A -->|"/doc-to-scenarios"| B
    B -->|"/review-scenario"| C[Reviewed<br/>scenario]
    C -->|"/scenario-to-tests"| D[Test suite]
```

Three quick-start authoring paths converge on `/scenario-to-tests`. See the [Workflow](workflow.md) page for a fourth path (LLM-authored documents, which routes through `/doc-to-scenarios`) and a side-by-side comparison.

A **scenario** is an LLM-optimized markdown representation of the flow you want to test — readable by humans, mechanically processable by Claude. You produce one by recording a browser session, crawling the site, or converting an existing document — each writes to its own partition (`scenarios/record/`, `scenarios/crawl/`, `scenarios/convert/`). Hand-edit or delete in place if you want; then `/review-scenario` audits against the live site, and `/scenario-to-tests` turns the reviewed scenarios into a runnable test suite at `<test_dir>/<command>/<scenario-name>/`.

## Quick start

```
/plugin marketplace add mattbobambrose/playwright-scenarios
/plugin install playwright-scenarios@playwright-scenarios
```

Then seed your first scenario:

=== "Record a flow"

    ```
    /record-scenario checkout-flow
    ```
    Opens a browser for you to demonstrate the flow.

=== "Crawl a site"

    ```
    /crawl-site https://your-site.com
    ```
    Claude explores the site and writes scenarios to `crawl/`.

=== "Convert a document"

    ```
    /doc-to-scenarios path/to/checkout-doc.md
    ```
    Evaluates and converts an existing document.

Then review and generate:

```
/review-scenario checkout-flow
/scenario-to-tests checkout-flow
```

## Learn more

<div class="grid cards" markdown>

-   :lucide-graduation-cap: **[Tutorial](tutorial.md)**

    ---

    Step-by-step walkthrough from installation to generated tests.

-   :lucide-book-open: **[Terminology](terminology.md)**

    ---

    Definitions for scenario, test case, source partition, fixture, tag, and more.

-   :lucide-git-branch: **[Workflow](workflow.md)**

    ---

    The full pipeline from document to generated tests, with decision points.

-   :lucide-check-circle: **[Capabilities](capabilities.md)**

    ---

    What the plugin can test, what it can't, and where gaps live instead.

-   :lucide-pencil: **[Writing Docs](writing-docs.md)**

    ---

    Guidance for writing documents that convert cleanly into scenarios.

</div>
