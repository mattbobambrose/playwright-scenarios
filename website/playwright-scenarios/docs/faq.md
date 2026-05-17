---
icon: lucide/circle-help
---

# FAQ

Conceptual and scope questions about the `playwright-scenarios` plugin. For runtime errors and "I tried X and got Y" debugging, see [Troubleshooting](troubleshooting.md) instead.

## Do I have to use the bookstore demo from the tutorial?

No — the bookstore demo is just a concrete target for the tutorial. Any URL Claude can reach via Playwright is fair game: your local dev server, a staging environment, a public site. Wherever the tutorial says `http://localhost:8080`, substitute your own URL. You can skip the `docker run` step in Step 1 entirely if you already have a server running.

The tutorial calls out every substitution under a **For your project:** note. The [Bring your own site](tutorial.md) preamble at the top of the tutorial summarizes what's swappable.

## Why do I need Node.js?

For `playwright-cli`, the binary that `/review-scenario`, `/scenario-to-tests`, and `/crawl-site` shell out to during their live-site exploration phase. It's distributed as an npm package (`@playwright/cli`), and npm requires Node.js. The dependency chain:

```
/review-scenario, /scenario-to-tests, /crawl-site
      ↓ invoke
playwright-cli skill
      ↓ wraps
@playwright/cli (npm package)
      ↓ installed via
npm install -g @playwright/cli@latest
      ↓ requires
Node.js
```

`/record-scenario` is the only authoring command that doesn't need `playwright-cli` — it launches Playwright codegen via the Gradle `recordScenario` task in your project. If you only ever record, Node.js is skippable.

## What if my project isn't Kotlin?

`/scenario-to-tests` currently generates only Kotlin + Kotest StringSpec tests with the Playwright-for-Java bindings. Python and TypeScript generators are planned but not yet shipped.

The rest of the pipeline is language-agnostic — `/crawl-site`, `/record-scenario`, `/doc-to-scenarios`, and `/review-scenario` all produce or operate on plain markdown scenarios. You can author scenarios for any web app today; you just can't auto-generate the tests for non-Kotlin stacks yet. When the matching generator lands, set `test_language` / `test_framework` in `.claude/playwright-scenarios.local.md` and re-run `/scenario-to-tests` against your existing scenarios.

## Which command should I use to author a scenario?

| Starting point | Use | Writes to |
|---|---|---|
| You have a written document (test plan, requirements doc, meeting notes, ACs) | [`/doc-to-scenarios <path>`](commands.md#doc-to-scenarios) | `<scenario_dir>/convert/` |
| You know the flow but have no document | [`/record-scenario [url]`](commands.md#record-scenario) | `<scenario_dir>/record/` |
| You don't know what flows exist yet | [`/crawl-site <start-url>`](commands.md#crawl-site) | `<scenario_dir>/crawl/` |

All three feed the same downstream pipeline: `/review-scenario` to audit against the live site, then `/scenario-to-tests` to generate executable tests. For the full decision tree, see [Workflow](workflow.md).
