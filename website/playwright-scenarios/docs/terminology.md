---
icon: lucide/book-open
---

# Terminology

## Inputs (what enters the plugin)

| Term | Definition |
|------|------------|
| **User story** | A stakeholder-facing description of desired behavior (e.g., "As a shopper, I can search for a book, add it to my cart, and complete checkout"). Not our format — this is what someone writes before testing. The `evaluate-spec` skill reads these. |
| **Spec** | A structured test document written by a human: numbered test cases, fixture tables, acceptance criteria, scope boundaries. Richer than a scenario but not in our format. Input to `/spec-to-scenarios`. Can be any format (markdown, Google Doc, Jira tickets). |
| **User flow** | A sequence of actions a real user takes to accomplish a goal (e.g., "search for a book and add it to the cart," "navigate from homepage to bestsellers"). The unit of work that `/crawl-site` discovers and `/record-scenario` captures. One user flow typically becomes one scenario. |

## Plugin artifacts (what the plugin works with)

| Term | Definition |
|------|------------|
| **Scenario** | A flat markdown file in our format (`# Title`, `**URL:**`, `## Test N:` blocks with Action/Expected pairs, plus extended tags). The plugin's central artifact — everything feeds into it and everything reads from it. One scenario = one user flow. |
| **Test case** | A single `## Test N:` section inside a scenario file. One scenario can have many test cases. Each becomes one test function in generated code. |
| **Draft** | A scenario file under `<scenario_dir>/drafts/`. Indicates "not yet reviewed by a human." Created by `/crawl-site` and `/spec-to-scenarios`. Ignored by `/review-scenario` and `/scenario-to-tests` unless `--include-drafts` is passed. Promoted by moving out of `drafts/`. |
| **Fixture** | A JSON file providing structured test data (customer profiles, shipping addresses, payment details) referenced by the `**Fixture:**` tag. One fixture can be shared across many scenarios. `**Branch:**` overrides individual fields for alternate-path testing. |
| **Tag** | A bold-label directive in the scenario format (`**Iframe:**`, `**Intercept:**`, `**Cookie:**`, etc.) that controls test generation behavior beyond basic Action/Expected pairs. Tags are metadata for the generator, not test steps. |

## Output (what the plugin produces)

| Term | Definition |
|------|------------|
| **Generated test** | The output of `/scenario-to-tests`: a Kotlin/TypeScript/Python test file extending the project's base test class. One file per scenario, one test function per test case. |

!!! info "Deliberately not formalized"
    **"test"** alone is too ambiguous — always qualify as "test case," "test file," or "test run." **"step"** is avoided because our format uses "Action bullet" to prevent collision with command-phase numbering.
