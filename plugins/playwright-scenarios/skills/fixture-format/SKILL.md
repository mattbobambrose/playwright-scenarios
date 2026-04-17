---
name: fixture-format
description: Defines the standardized fixture file format (JSON) for typed test data shared across all test generators (Kotlin, TypeScript, Python). Use when creating, editing, or validating fixture files referenced by the **Fixture:** tag in scenario markdown. Triggered when Claude creates or modifies files under a fixtures/ directory or when the user asks about fixture structure.
---

# Fixture Format

Fixture files provide structured test data (personas, form inputs, expected values) that scenarios reference via the `**Fixture:** <path>` tag. This skill defines the canonical format so all generators (Kotlin, TypeScript, Python) read from the same source file.

## File format

Fixtures are JSON files with a `.json` extension, stored under a `fixtures/` directory relative to `<SCENARIO_DIR>`. The `**Fixture:**` tag path is relative to `<SCENARIO_DIR>`.

Example path: `**Fixture:** fixtures/returning-customer` → reads `<SCENARIO_DIR>/fixtures/returning-customer.json`.

## Schema

A fixture is a flat or nested JSON object where top-level keys represent logical groups (screens, pages, or categories) and leaf values are the data to enter or assert.

```json
{
  "_meta": {
    "name": "Alex Rivera",
    "description": "Returning customer with saved address and payment method",
    "created": "2026-04-16",
    "source": "Checkout_Flow_QA_Spec.md"
  },
  "account": {
    "first_name": "Alex",
    "last_name": "Rivera",
    "email_prefix": "alex-test",
    "password": "SecurePass123!"
  },
  "shipping": {
    "address": "123 Main St",
    "city": "Portland",
    "state": "OR",
    "zip": "97201",
    "country": "US"
  },
  "payment": {
    "card_number": "4242424242424242",
    "expiry": "12/28",
    "cvc": "123"
  },
  "preferences": {
    "genres": [
      "sci-fi",
      "mystery",
      "biography"
    ],
    "notifications": "weekly_digest"
  },
  "cart": {
    "items": [
      "978-0-06-112008-4",
      "978-0-14-028329-7"
    ]
  }
}
```

### Required fields

- **`_meta.name`** — human-readable persona name. Used in reports and fixture selection prompts.
- **`_meta.description`** — one-line description of what this persona represents.

All other fields are domain-specific and defined by the project's needs.

### Naming conventions

- File names are kebab-case: `returning-customer.json`, `guest-checkout.json`, `empty-cart.json`.
- Top-level keys are snake_case groups: `account`, `shipping`, `payment`, `preferences`.
- Leaf keys match DOM identifiers when possible: use `sci-fi` (matching `data-category="sci-fi"`) rather than `Science Fiction`.
- Array values for multi-select fields (genres, cart items) use the DOM identifier form.

### Values

- **Strings** for text inputs and single-select values.
- **Numbers** for numeric inputs (quantity, price).
- **Arrays of strings** for multi-select fields (genres, cart items).
- **Booleans** for checkbox state — but prefer string values matching the DOM (`"yes"`, `"no"`) over `true`/`false` when the form uses radio buttons.
- **`null`** for fields that should be left empty (tests the "required field" validation).

## How generators use fixtures

### Kotlin + Kotest (current)

The generator reads the JSON file at test startup and makes values available to test code. A typical pattern:

```kotlin
val fixture = Json.decodeFromString<JsonObject>(
    File("src/test/scenarios/fixtures/returning-customer.json").readText()
)
val firstName = fixture["account"]!!.jsonObject["first_name"]!!.jsonPrimitive.content
```

### TypeScript + Playwright (future)

```typescript
import fixture from '../fixtures/returning-customer.json';
await page.getByLabel('First name').fill(fixture.account.first_name);
```

### Branch overrides

When a scenario uses `**Branch:** shipping.country = CA`, the generator:
1. Loads the base fixture.
2. Deep-merges the override (`shipping.country = CA`).
3. Runs the flow with the modified data.

The fixture file itself is never modified. The override is applied at runtime.

## Fixture variants vs. branches

- Use **separate fixture files** when two personas have substantially different data (different shipping address, different payment method, different cart contents). E.g., `returning-customer.json` vs. `guest-checkout.json`.
- Use **`**Branch:**` with a single fixture** when you're testing one field's effect on the flow (international shipping surcharge, expired card, empty cart). The fixture stays the same except for the overridden field.

## Validation

When reading a fixture, the generator should:
1. Verify the file exists and is valid JSON.
2. Verify `_meta.name` is present (warn if not — it's required for reports but doesn't break tests).
3. Not fail on unknown keys — fixtures are extensible. The generator reads only the keys it needs.

## What this skill does NOT do

- It does not create fixture files — use `/generate-fixture` for that.
- It does not validate fixture values against the live site — that happens during `/review-scenario` and `/scenario-to-tests`.
- It does not define domain-specific schemas — each project's fixture structure depends on its forms and flows.
