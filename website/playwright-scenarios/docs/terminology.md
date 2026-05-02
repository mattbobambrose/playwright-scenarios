---
icon: lucide/book-open
---

# Terminology

## Input (what enters the plugin)

| Term | Definition |
|------|------------|
| **Doc** | Any document describing what to test — requirements docs, test plans, meeting notes, acceptance criteria, Jira tickets. Not in scenario format yet. Input to `evaluate-doc` and `/doc-to-scenarios`. A doc typically contains multiple user flows (e.g., "search for a book and add it to the cart," "navigate from homepage to bestsellers"), each of which becomes one scenario. |

## Plugin artifacts (what the plugin works with)

| Term | Definition |
|------|------------|
| **Scenario** | A flat markdown file in our format (`# Title`, `**URL:**`, `## Test N:` blocks with Action/Expected pairs, plus extended tags). The plugin's central artifact — everything feeds into it and everything reads from it. One scenario = one user flow from a doc. |
| **Test case** | A single `## Test N:` section inside a scenario file. One scenario can have many test cases. Each becomes one test function in generated code. |
| **Source partition** | The subdirectory under `<scenario_dir>` that records *which command produced* a scenario. Three partitions: `<scenario_dir>/record/` (from `/record-scenario`), `<scenario_dir>/crawl/` (from `/crawl-site`), `<scenario_dir>/convert/` (from `/doc-to-scenarios`). Generated tests mirror this partition under `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`. There is no draft state — the scenario in its partition is the canonical artifact; users hand-edit or delete in place if they want, then run `/review-scenario`. |
| **Fixture** | A JSON file providing structured test data (customer profiles, shipping addresses, payment details) referenced by the `**Fixture:**` tag. One fixture can be shared across many scenarios. `**Branch:**` overrides individual fields for alternate-path testing. |
| **Tag** | A bold-label directive in the scenario format (`**Iframe:**`, `**Intercept:**`, `**Cookie:**`, etc.) that controls test generation behavior beyond basic Action/Expected pairs. Tags are metadata for the generator, not test steps. |

## Output (what the plugin produces)

| Term | Definition |
|------|------------|
| **Generated test** | The output of `/scenario-to-tests`: a Kotlin/TypeScript/Python test file extending the project's base test class. One file per scenario, one test function per test case. |

!!! info "Deliberately not formalized"
    **"test"** alone is too ambiguous — always qualify as "test case," "test file," or "test run." **"step"** is avoided because our format uses "Action bullet" to prevent collision with command-phase numbering.
