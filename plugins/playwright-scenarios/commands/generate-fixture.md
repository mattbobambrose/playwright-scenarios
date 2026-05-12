---
name: generate-fixture
description: Generate a fixture JSON file from a scenario's input data bullets, a document's persona table, or interactive prompts. Outputs the standardized fixture format defined by the fixture-format skill.
summary: Generate a fixture JSON file from a scenario's data bullets, a document's persona table, or interactive prompts.
signature: /generate-fixture <source | interactive> [--name=N]
arguments:
  - name: source
    description: Required. Either a scenario file path, a document path, or the keyword "interactive" to build from prompts. Optionally followed by --name=<fixture-name> to set the output filename.
    required: true
---

# Generate Fixture

Create a fixture JSON file in the format defined by the `fixture-format` skill. The fixture lands in `<SCENARIO_DIR>/fixtures/<name>.json`.

## Argument parsing

The first non-flag token is the **source** (required):

- A path to a `.md` file in `<SCENARIO_DIR>` → extract input data bullets from the scenario.
- A path to any other file → treat as a document and extract persona/fixture tables.
- The literal string `interactive` → prompt the user for each field.

Flags:

- `--name=<fixture-name>` — kebab-case name for the output file. If omitted, inferred from the source (scenario name, persona name from the document, or prompted in interactive mode).

Any unknown `--`-prefixed token → error before doing any work.

## Phase 0: Load config

Invoke `loading-config` to resolve `<SCENARIO_DIR>`. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair. Ensure `<SCENARIO_DIR>/fixtures/` exists; create if not.

## Phase 1: Extract data

### From a scenario file

Read the scenario markdown. Collect all input data bullets (`- **Email:** ...`, `- **Password:** ...`, etc.) and any `**Fixture:**` reference that already exists. Group by the `## Test N:` section they appear in.

Build a fixture object:
- Top-level keys = logical groups inferred from the data (e.g., all email/password/name fields → `account` or `basics`).
- Leaf values = the literal values from the bullets.
- If the scenario already has a `**Fixture:**` tag pointing to an existing file, read that file and merge — new values from the scenario override existing fixture values.

### From a document

Read the document. Look for structured data in these forms:
- **Tables** with columns like "Screen", "Field", "Value" or "Input", "Expected".
- **Persona blocks** with labeled key-value pairs.
- **Numbered field lists** within test case definitions.

Build a fixture object mapping the document's structure to the `fixture-format` skill's schema. Use the document's own grouping (by screen, by category) as top-level keys.

### Interactive mode

Use `AskUserQuestion` to build the fixture incrementally:

1. Ask for the persona name and one-line description (→ `_meta`).
2. Ask for logical groups: "What data categories does this persona have? (e.g., basics, diagnosis, symptoms)" — multi-select with common options plus "Other".
3. For each group, ask for field names and values. Use free-text input.
4. Confirm the complete fixture before writing.

## Phase 2: Build the JSON

Assemble the fixture following the `fixture-format` skill's schema:

```json
{
  "_meta": {
    "name": "<persona name>",
    "description": "<one-line description>",
    "created": "<today's date>",
    "source": "<source file or 'interactive'>"
  },
  ...data groups...
}
```

Apply naming conventions from the `fixture-format` skill:
- Top-level keys: snake_case.
- Leaf keys: match DOM identifiers when available (e.g., `sci-fi` not `Science Fiction`).
- Arrays for multi-select fields.
- Strings for text inputs, numbers for numeric inputs.

## Phase 3: Check for collisions

If `<SCENARIO_DIR>/fixtures/<name>.json` already exists:
- Show the user a diff between the existing and new fixture.
- Use `AskUserQuestion`: "Fixture already exists. Overwrite, merge, or pick a new name?" Options: `Overwrite`, `Merge (new values win)`, `Pick a new name`.
- If merge: deep-merge new values into existing, preserving keys not present in the new data.

## Phase 4: Write the fixture

Write the JSON file to `<SCENARIO_DIR>/fixtures/<name>.json` with 2-space indentation.

## Phase 5: Report

Tell the user:
- The path of the written fixture file.
- The number of groups and fields.
- If the source was a scenario, suggest updating it to use `**Fixture:** fixtures/<name>` instead of inline data bullets.
- If the source was a document, suggest running `/doc-to-scenarios` to convert the document's test cases using this fixture.
