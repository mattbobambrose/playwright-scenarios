---
icon: lucide/terminal
---

# Commands & Skills

Every component shipped by the `playwright-scenarios` plugin, with signatures, flags, and examples. For walkthrough-style documentation, see the [Tutorial](tutorial.md). For decision trees on which command to reach for, see the [Workflow](workflow.md) page.

## Quick reference

| Command | Purpose |
|---|---|
| [`/playwright-scenarios-config`](#playwright-scenarios-config) | View or change the plugin's per-project settings |
| [`/scaffold-base-test`](#scaffold-base-test) | Generate a Kotlin `BasePageTest` so generated tests have something to extend |
| [`/record-scenario`](#record-scenario) | Capture a flow by driving a real browser (writes to `record/`) |
| [`/crawl-site`](#crawl-site) | Auto-discover flows by exploring a site (writes to `crawl/`, read-only) |
| [`/doc-to-scenarios`](#doc-to-scenarios) | Convert a document into scenarios (writes to `convert/`) |
| [`/generate-fixture`](#generate-fixture) | Scaffold a fixture JSON file |
| [`/review-scenario`](#review-scenario) | Audit a scenario against the live site |
| [`/scenario-to-tests`](#scenario-to-tests) | Generate test code from reviewed scenarios |
| [`/scenario-status`](#scenario-status) | Health dashboard across scenarios and tests |

| Skill | Purpose |
|---|---|
| [`loading-config`](#loading-config) | Resolve `.claude/playwright-scenarios.local.md` |
| [`authoring-scenarios`](#authoring-scenarios) | Conventions for hand-writing scenario markdown |
| [`fixture-format`](#fixture-format) | Canonical JSON fixture schema |
| [`evaluate-doc`](#evaluate-doc) | Score a document's testability before conversion |
| [`debugging-scenarios`](#debugging-scenarios) | Diagnose failing generated tests |
| [`scaffold-base-test`](#scaffold-base-test-skill) | Render and write the Kotlin `BasePageTest` template |

## Argument-syntax conventions

- `<arg>` — required positional argument
- `[arg]` — optional positional argument
- `[name1 name2 ...]` — zero or more positional arguments
- `--flag` — boolean flag (off by default unless noted)
- `--flag=<value>` — flag that takes a value
- Flags can be mixed with positional arguments in any order. Unknown `--`-prefixed tokens are an error.

---

## Commands

### `/playwright-scenarios-config`

```
/playwright-scenarios-config
```

View or change the plugin's per-project settings stored in `.claude/playwright-scenarios.local.md`. Also the recovery path when that file is malformed and other commands refuse to load it.

**Arguments:** none.

**What it does:**

1. Reads `.claude/playwright-scenarios.local.md` directly. If missing, runs the normal interactive bootstrap (the `loading-config` skill).
2. If malformed, prints the offending content with a one-line diagnosis and asks whether to overwrite.
3. If clean, shows a table of current values and lets you change any field.

---

### `/scaffold-base-test`

```
/scaffold-base-test
```

Generate a Kotlin `BasePageTest` class so [`/scenario-to-tests`](#scenario-to-tests) has a base class to extend. Without one, generated tests are emitted with no `extends` clause and a TODO comment at the top of every file. Run this once per project; the resulting class is registered as `base_test_class` in `.claude/playwright-scenarios.local.md` and reused thereafter.

Most users hit this skill indirectly: when [`loading-config`](#loading-config) runs its base-test-class discovery and finds zero candidates, it offers to scaffold one. Run the command explicitly only when you want to (re)generate the file or when you originally said "No" to the auto-offer.

**Arguments:** none.

**What it does:**

1. Loads the project config and aborts if the language/framework combo isn't `kotlin` + `kotest-stringspec` (the only combo currently wired).
2. Aborts if `base_test_class` is already set in the config — to regenerate, remove that line from `.claude/playwright-scenarios.local.md` first.
3. Resolves where the file should go: parent of `<test_dir>`, sibling to the scenarios directory. For example, `<test_dir> = src/test/kotlin/com/example/qa/scenarios` produces `src/test/kotlin/com/example/qa/BasePageTest.kt`.
4. Prompts for three customizations:

    | Prompt | Choices | Default |
    |---|---|---|
    | Reset endpoint | Whether the dev server has a `POST /reset` that clears state between specs. If yes, the scaffold emits `resetServerState()` and calls it from the lifecycle hook. | Yes |
    | Lifecycle scope | `Per spec` (one Browser/Page per spec class, faster, shared state across tests in the spec) or `Per test` (fresh Browser/Page per test, slower, full isolation). | Per spec |
    | Browser | `Chromium`, `Firefox`, or `Webkit`. | Chromium |

5. Writes the rendered `BasePageTest.kt` and persists the new FQN to `base_test_class` in the config.

**Prerequisites:** `test_language = kotlin` and `test_framework = kotest-stringspec` in the project config. No external binaries — the scaffold is pure file generation.

**Refusals:**

- Target file `BasePageTest.kt` already exists at the resolved path → asks you to delete it first. Existing customizations are never silently overwritten.
- `base_test_class` already set in config → asks you to remove that line first.
- `test_language` ≠ `kotlin` or `test_framework` ≠ `kotest-stringspec` → no Kotlin scaffold is appropriate; nothing is written.

**Customizing further:**

The scaffolded file is yours to edit. Common follow-ups:

- Override `baseUrl` in your concrete test class to point at a different server.
- Read the headless flag from an env var instead of `System.getProperty("playwright.headless", "true")`.
- Add cookies, storage state, or auth fixtures by extending the `Browser.NewContextOptions()` call.
- Switch browsers per-test by maintaining multiple subclasses of `BasePageTest`.

---

### `/record-scenario`

```
/record-scenario [name]
```

Create a scenario by demonstrating a flow in a real browser. Launches Playwright codegen, captures clicks/typing/marked assertions, and writes a scenario file to `<SCENARIO_DIR>/record/<name>.md`.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `name` | optional, kebab-case | Scenario filename without `.md`. If omitted, inferred from the recorded actions. |

**Flags:** none.

**Examples:**

```
/record-scenario
/record-scenario checkout-flow
```

**Prerequisites:** The host project must define a `recordScenario` Gradle task. The language template repos linked from the [Tutorial](tutorial.md) include this task pre-configured.

---

### `/crawl-site`

```
/crawl-site <start-url> [description] [--depth=N] [--max-scenarios=N]
```

Crawl a site starting from a URL, identify plausible user flows, and write scenarios to `<SCENARIO_DIR>/crawl/`. **Strictly read-only:** never fills inputs, never submits forms, never clicks state-changing buttons. For interactive flows use `/record-scenario`.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `start-url` | required | The first token starting with `http://` or `https://`. |
| `description` | optional | Free-form natural-language scope (e.g., "focus on the checkout flow"). Everything that isn't the URL or a flag is joined as the description. If neither a description nor any flag is given, the command prompts interactively with a short menu (Structural / Shallow / Deep). |

**Flags:**

| Flag | Description |
|---|---|
| `--depth=N` | Override the interpreted crawl depth. Clamped to `[1, 3]`. Default: interpreted from the description (or `1` if no description). |
| `--max-scenarios=N` | Cap the number of scenarios emitted. Default `10`. |

**Examples:**

```
/crawl-site https://bookstore.example.com                 # bare URL → interactive menu
/crawl-site https://bookstore.example.com --depth=3       # flag-only → defaults, no menu
/crawl-site https://bookstore.example.com focus on the checkout flow for a first-time buyer
/crawl-site https://bookstore.example.com thorough crawl of all product pages --max-scenarios=15
/crawl-site https://bookstore.example.com shallow overview of the main navigation
```

**Prerequisites:** `playwright-cli` available on `PATH` or via `npx`.

---

### `/doc-to-scenarios`

```
/doc-to-scenarios <source> [--skip-evaluation]
```

Convert any document (test plan, requirements doc, meeting notes, acceptance criteria) into one or more scenario markdown files under `<SCENARIO_DIR>/convert/`. By default runs the `evaluate-doc` skill first and pauses for review.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `source` | required | Path to the source document. |

**Flags:**

| Flag | Description |
|---|---|
| `--skip-evaluation` | Assume the document has already been evaluated; skip the inline `evaluate-doc` pass. |

**Examples:**

```
/doc-to-scenarios path/to/checkout-doc.md
/doc-to-scenarios path/to/checkout-doc.md --skip-evaluation
```

!!! tip
    For best results, paste [DOC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/DOC_GUIDE.md) into your authoring LLM's context before generating the document.

---

### `/generate-fixture`

```
/generate-fixture <source | interactive> [--name=<fixture-name>]
```

Scaffold a fixture JSON file in the format defined by the [`fixture-format`](#fixture-format) skill. Output lands at `<SCENARIO_DIR>/fixtures/<name>.json`.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `source` | required | Either a path to a `.md` scenario file (extracts input data bullets), a path to any other file (extracts persona/fixture tables), or the literal `interactive` (prompts for each field). |

**Flags:**

| Flag | Description |
|---|---|
| `--name=<fixture-name>` | Kebab-case output filename. If omitted, inferred from the source or prompted in interactive mode. |

**Examples:**

```
/generate-fixture interactive --name=returning-customer
/generate-fixture src/test/scenarios/checkout-flow.md
/generate-fixture docs/personas.md --name=premium-buyer
```

---

### `/review-scenario`

```
/review-scenario [name1 name2 ...]
```

Audit one or more scenario files across `<SCENARIO_DIR>/{record,crawl,convert}/` against the live site, propose improvements, and rewrite the markdown in place. Does **not** generate tests — pair with `/scenario-to-tests` for that.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `name1 name2 ...` | optional, zero or more | Scenario names without `.md`, or a partition name (`record`, `crawl`, `convert`) to scope the review to that partition. Empty = review every scenario across all three partitions. If a name matches in multiple partitions, you'll be prompted to disambiguate or use the `partition/name` form. |

**Flags:** none.

**Examples:**

```
/review-scenario
/review-scenario record
/review-scenario checkout-flow
/review-scenario checkout-flow add-to-cart
/review-scenario record convert
```

**Prerequisites:** `playwright-cli` available on `PATH` or via `npx`.

---

### `/scenario-to-tests`

```
/scenario-to-tests [name1 name2 ...] [--dry-run]
```

Generate test code from reviewed scenarios. The output language and framework come from `.claude/playwright-scenarios.local.md`. Currently fully wired for **Kotlin + Kotest StringSpec**. Tests are written to `<TEST_DIR>/<command>/<scenario-name>/<ClassName>.kt`, partitioned by source command and by scenario.

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `name1 name2 ...` | optional, zero or more | Scenario names without `.md`, or a partition name (`record`, `crawl`, `convert`) to scope generation to that partition. Empty = generate tests for every scenario across all three partitions. |

**Flags:**

| Flag | Description |
|---|---|
| `--dry-run` | Write the test files but skip running them. |

**Examples:**

```
/scenario-to-tests
/scenario-to-tests record
/scenario-to-tests checkout-flow
/scenario-to-tests checkout-flow add-to-cart
/scenario-to-tests --dry-run
```

---

### `/scenario-status`

```
/scenario-status
```

Single-view health dashboard for every scenario and its generated tests, plus crawl-derived coverage metrics.

**Arguments:** none.

**Reports:**

- File path, title, URL, test count, presence of fixtures/prerequisites/extended tags
- Provenance (which command authored the file)
- When the scenario was last reviewed
- Whether a generated test file exists and is fresh (newer than the scenario)
- Latest pass/fail status from the test run
- Crawl depth and flow-type coverage (when crawl metadata exists)
- Conversion rate (scenarios with generated tests / total scenarios)
- Critical-path coverage (requires `.critical-paths.md`)

---

## Skills

Skills are auto-loaded by Claude when their description matches the active task. You don't invoke them directly; commands and Claude itself trigger them.

### `loading-config`

Resolves `.claude/playwright-scenarios.local.md` and returns the four required fields (`scenario_dir`, `test_dir`, `test_language`, `test_framework`) plus optional `source_root` and `base_test_class`. Triggers automatically at the start of every plugin command. On first run, prompts the user and writes the file. Returns `MALFORMED_CONFIG: <reason>` when the file is unreadable, which commands handle by directing the user to `/playwright-scenarios-config`.

### `authoring-scenarios`

Defines the flat scenario-markdown format that `/review-scenario` audits and `/scenario-to-tests` consumes. Triggers when Claude creates or modifies a `.md` file under `<SCENARIO_DIR>`, or when the user asks about scenario format. Covers file structure (`# Title`, `**URL:**`, `## Test N:` blocks with Action/Expected pairs) and the 13 extended tags. See [Capabilities](capabilities.md) for the full tag table.

### `fixture-format`

Canonical JSON schema for fixture files referenced by the `**Fixture:**` tag. Triggers when Claude creates or modifies files under a `fixtures/` directory or when the user asks about fixture structure. Used by `/generate-fixture` to produce conformant output and by `/scenario-to-tests` to read fixtures back.

### `evaluate-doc`

Reads any document and produces a structured testability report — what converts directly, what needs modification, and what is out of scope. Advisory only: never writes scenario files. Invoked inline by `/doc-to-scenarios` (unless `--skip-evaluation` is passed) and on demand when the user asks "can we test this?" about an existing document.

### `debugging-scenarios`

Diagnoses tests generated by `/scenario-to-tests` that fail. Triggers when the user reports test failures. Works through common root causes in order — undeclared iframe, stale selectors, race conditions, base-class misconfiguration, missing fixture data — with detection method and fix for each.

### `scaffold-base-test` {: #scaffold-base-test-skill }

Renders the Kotlin `BasePageTest` template and writes it to disk. Owns the three customization prompts (`/reset` endpoint, lifecycle scope, browser) and the variant rules that compose them with the canonical template. Invoked by [`/scaffold-base-test`](#scaffold-base-test) (explicit) and by [`loading-config`](#loading-config) (auto-offered when zero base-test-class candidates are found in the project). Currently supports `kotlin` + `kotest-stringspec` only; additional language/framework variants will land alongside their `/scenario-to-tests` generation paths. After scaffolding, `base_test_class` is recorded in `.claude/playwright-scenarios.local.md` automatically.
