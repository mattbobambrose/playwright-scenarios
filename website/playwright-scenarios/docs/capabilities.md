---
icon: lucide/check-circle
---

# Capabilities

## What the plugin can test

The scenario pipeline (`/record-scenario` or `/crawl-site` → `/review-scenario` → `/scenario-to-tests`) is built for:

| Capability | How | Tag |
|------------|-----|-----|
| Multi-page user flows | Wizard forms, checkout flows, login sequences, onboarding funnels | — |
| DOM state assertions | Element visibility, text content, CSS classes, attribute values | `**Expected:**` |
| Form interactions | Fill, click, select, checkbox, progressive disclosure | `**Action:**` |
| Cross-page navigation | URL changes, redirects, iframe transitions | `**Iframe:**` |
| Alternate-path testing | Override one fixture field to test a different flow path | `**Branch:**` |
| Regression guards | Mark known bugs that flip to real failures when fixed | `**Expected failure:**` |
| Nondeterministic content | Regex match for LLM-generated or variable text | `**Expected (regex):**` |
| Flow-wide invariants | Console errors, network failures, layout stability | `**Assert throughout:**` |
| Shared setup | Reuse one expensive flow run across multiple scenarios | `**Prerequisite:**` |
| Typed test data | Persona-driven testing with standardized JSON fixtures | `**Fixture:**` |
| Error and edge-case testing | Mock network requests for API failures, empty states | `**Intercept:**` |
| State pre-seeding | Auth tokens, feature flags, A/B buckets, locale preferences | `**Cookie:**`, `**Storage:**` |
| Device emulation | Playwright device presets (viewport + user-agent) | `**Device:**` |
| Test lifecycle | Custom timeouts and teardown actions | `**Timeout:**`, `**Cleanup:**` |

## What the plugin cannot test

| Category | Example | Why not | Where it lives instead |
|----------|---------|---------|------------------------|
| **Cross-run comparison** | "Run twice, diff the output" | Scenarios describe one run, not a comparison between runs | Custom test code with explicit diffing |
| **Performance / timing** | "Page loads within 2 seconds" | Scenarios describe *what* happens, not *how fast* | Test code with explicit timeouts |
| **Visual regression** | "Screen matches a reference screenshot" | Scenarios are text-based, not pixel-based | Playwright screenshot comparison or Percy/Chromatic |
| **Accessibility** | WCAG compliance, screen reader behavior | Needs specialized tooling (axe-core, etc.) | Dedicated a11y test suite |
| **Network-layer testing** | API response codes, request/response bodies | Scenarios test the UI, not the API | API test suite or Playwright route interception in code |
| **Stateful branching logic** | "If user answers X, path Y opens" | Each scenario is a single linear flow | Write one scenario per branch; use different fixture data to drive each path |

!!! note "Branching workaround"
    While the plugin can't express `if/else` in a single scenario, you can use `**Branch:**` + `**Fixture:**` to test each path as a separate scenario file that shares the same base fixture with one field overridden.
