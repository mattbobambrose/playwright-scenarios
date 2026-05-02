---
name: doc-to-scenarios
description: Convert any document (test plan, requirements doc, meeting notes, acceptance criteria) into scenario markdown files. Requires the evaluate-doc skill to have been run first (or runs it inline). The bridge between evaluation and the /review-scenario → /scenario-to-tests pipeline.
arguments:
  - name: source
    description: Required. Path to the source document to convert. Optionally followed by flags. Supported flags - --skip-evaluation (assume the doc has already been evaluated; skip the evaluate-doc pass), --promote (write directly to <SCENARIO_DIR> instead of <SCENARIO_DIR>/drafts/).
    required: true
---

# Doc To Scenarios

Convert any document into scenario markdown files that feed the existing `/review-scenario` → `/scenario-to-tests` pipeline. The input can be a test plan, requirements doc, meeting notes, acceptance criteria, or any structured description of what to test. This is the automated counterpart to hand-writing scenarios.

By default, output goes to `<SCENARIO_DIR>/drafts/` so the user can review before promoting. Pass `--promote` to write directly to `<SCENARIO_DIR>`.

## Argument parsing

The first non-flag token is the **source document path** (required). Split remaining args into flags:

- `--skip-evaluation` — skip the inline evaluate-doc pass. Use when the user already ran `evaluate-doc` on this document and reviewed the report. Without this flag, the command runs evaluation first and pauses for the user to review before converting.
- `--promote` — write scenario files directly to `<SCENARIO_DIR>` instead of `<SCENARIO_DIR>/drafts/`.

Any unknown `--`-prefixed token → error before doing any work. Missing source path → error.

## Phase 0: Load config

Invoke the `loading-config` skill to resolve `<SCENARIO_DIR>`. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair.

Ensure the output directory exists (`<SCENARIO_DIR>/drafts/` or `<SCENARIO_DIR>` depending on `--promote`).

## Phase 1: Read and evaluate the source document

1. Read the source document in full.
2. Unless `--skip-evaluation` was passed, invoke the `evaluate-doc` skill to produce a testability report. Present the report to the user and pause with `AskUserQuestion`: "Proceed with conversion? Review the report above — items marked 'out-of-scope' will be skipped, and 'needs-changes' items will be converted with best-effort and flagged for review." Options: `Yes, convert` (Recommended), `No, I'll make changes first`.
3. If the user chose to stop, report the evaluation and exit.

## Phase 2: Extract and map test cases

For each test case the evaluation classified as `direct`, `needs-changes`, or `extended-tag`:

1. **Determine which scenario file it belongs to.** Group related test cases into scenario files by:
   - Shared starting URL → same scenario.
   - Shared fixture / persona → same scenario.
   - Sequential steps in one flow → same scenario, sequential `## Test N:` sections.
   - Independent flows on the same page → separate scenarios.

2. **Map to scenario format.** For each test case:
   - Extract the URL from the document. If the document uses relative paths, preserve them.
   - Convert assertions to `- **Action:**` and `- **Expected:**` pairs following the `authoring-scenarios` skill's voice and selector rules.
   - Map extended elements to the correct tags:
     - Known bugs → `**Expected failure:** <reason>` on the relevant test.
     - Persona/fixture tables → `**Fixture:** <path>` at the top (the fixture file itself is NOT created here — use `/generate-fixture` for that).
     - Shared setup flows → `**Prerequisite:** <scenario-name> (Tests N-M)`.
     - Flow-wide checks → `**Assert throughout:** <assertion>`.
     - Nondeterministic content → `**Expected (regex):** <pattern>`.
     - Iframe boundaries → `**Iframe:** <selector>`.
     - Alternate-path tests → `**Branch:** <field> = <value>` (requires a `**Fixture:**` tag).
     - Network mocking → `**Intercept:** <url-pattern> → <status> [body]`.
     - Pre-set cookies → `**Cookie:** <name>=<value>`.
     - Pre-set storage → `**Storage:** <key>=<value>`.
     - Device emulation → `**Device:** <preset>`.
     - Custom timeouts → `**Timeout:** <ms>`.
     - Teardown → `**Cleanup:** <action>`.

3. **Handle `needs-changes` items.** Convert with best effort and add a blockquote warning inside the scenario:
   > ⚠️ Converted from document with known issues: <list issues from evaluation>. Review and fix before using with `/scenario-to-tests`.

4. **Skip `out-of-scope` items.** Do not emit scenario content for these. They'll appear in the final report.

## Phase 3: Generate scenario names

For each scenario file to be written:

1. Derive a kebab-case name from the primary flow (e.g., `checkout-happy-path`, `book-search-filters`, `intl-shipping-surcharge`).
2. Check for collisions in the output directory. Increment the numeric suffix (`-v2`, `-v3`, ...) until a free name is found. Do not silently overwrite.

## Phase 4: Write scenario files (parallel subagents)

Launch subagents in **batches of at most 5 concurrent**. Each subagent writes one scenario file following the `authoring-scenarios` skill format.

Each file includes:
- A provenance blockquote: `> Converted from \`<source-filename>\` by \`/doc-to-scenarios\`. Review before feeding into \`/scenario-to-tests\`.`
- All mapped test cases for that scenario.
- Any `needs-changes` warnings inline.

## Phase 5: Report

Print a summary:

| Scenario file | Tests | Source test cases | Warnings |
|---------------|-------|-------------------|----------|

Then list:
- **Skipped (out-of-scope):** each out-of-scope test case with the reason and where it should live instead.
- **Needs review:** each `needs-changes` item that was converted with warnings.
- **Next steps:**
  1. Review drafts: `cat <SCENARIO_DIR>/drafts/<name>.md`
  2. If fixtures were referenced, run `/generate-fixture` to create the fixture files.
  3. Promote when ready: move from `drafts/` to `<SCENARIO_DIR>/`.
  4. Run `/review-scenario <name>` to verify against the live site.
  5. Run `/scenario-to-tests <name>` to generate test code.

Do **not** auto-chain into `/review-scenario` — the user should inspect the drafts first.
