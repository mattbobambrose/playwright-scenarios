# playwright-scenarios

[![GitHub Release](https://img.shields.io/github/v/release/mattbobambrose/playwright-scenarios)](https://github.com/mattbobambrose/playwright-scenarios/releases)

Claude Code marketplace for scenario-driven Playwright testing — record scenarios by driving a browser, audit them against the live site, and generate JVM Playwright + Kotest tests from the reviewed markdown.

## Tutorial

Start with the **[step-by-step tutorial](https://mattbobambrose.github.io/playwright-scenarios/)** — it walks through the full workflow from installation to generated tests.

## LLM Guides

Two reference documents ship with the plugin for different stages of the workflow:

- **[DOC_GUIDE.md](plugins/playwright-scenarios/DOC_GUIDE.md)** — Paste into any LLM's system prompt (ChatGPT, Claude, Gemini, Copilot) when writing test documents. LLM-agnostic. Covers what the test framework can and can't handle, 10 authoring rules, a document template, and a self-evaluation checklist. Use this *before* testing, when generating the docs that eventually become scenarios.

- **[USAGE.md](plugins/playwright-scenarios/USAGE.md)** — Add to your project's CLAUDE.md so Claude Code knows how to use the plugin. Covers all 8 commands, 13 tags, workflow, do's/don'ts, and troubleshooting. Use this *during* testing, when running the plugin commands.

## Installation

Add this marketplace to your Claude Code installation:

```
/plugin marketplace add mattbobambrose/playwright-scenarios
```

Then install the plugin:

```
/plugin install playwright-scenarios@playwright-scenarios
```

## Updating

```
/plugin marketplace update playwright-scenarios
/plugin update playwright-scenarios@playwright-scenarios
```

## Plugin

### playwright-scenarios

Author browser-driven scenarios as markdown, audit them against the live site, and generate JVM Playwright + Kotest tests.

```
/plugin install playwright-scenarios@playwright-scenarios
```

**Commands**

| Command | Description |
|---------|-------------|
| `/record-scenario [name]` | Launch Playwright codegen, capture a real user flow, and write a scenario to `<scenario_dir>/record/<name>.md`. |
| `/crawl-site <url> [description] [--depth=N] [--max-scenarios=N]` | Read-only crawl of a site. Accepts natural-language descriptions ("focus on checkout flow") to guide scope. Emits scenarios to `<scenario_dir>/crawl/`. |
| `/doc-to-scenarios <path> [--skip-evaluation]` | Convert any document into scenario markdown files under `<scenario_dir>/convert/`. Runs `evaluate-doc` first, then maps test cases to the scenario format with proper tags. |
| `/generate-fixture <source \| interactive> [--name=N]` | Scaffold a fixture JSON file from a scenario's data bullets, a document's persona table, or interactive prompts. |
| `/review-scenario [names...]` | Audit scenarios across `<scenario_dir>/{record,crawl,convert}/` against the live site and apply improvements to the markdown. A bare partition name scopes the review to that partition. |
| `/scenario-to-tests [names...] [--dry-run]` | Generate tests (defaults: Kotlin + Kotest StringSpec with Playwright-for-Java) at `<test_dir>/<command>/<scenario-name>/<ClassName>.kt`. A bare partition name scopes generation to that partition. |
| `/scenario-status` | Health dashboard grouped by partition: review dates, test status, pass/fail, plus coverage completeness (crawl depth, flow types, conversion rate, critical paths). |
| `/playwright-scenarios-config` | View or update per-project settings. Also the recovery path for malformed config files. |

**Skills**

| Skill | Description |
|-------|-------------|
| `loading-config` | Reads `.claude/playwright-scenarios.local.md` and bootstraps it on first use; invoked at the start of every command |
| `authoring-scenarios` | Flat-markdown format reference with 13 extended tags; used when hand-writing or editing scenario files |
| `evaluate-doc` | Evaluates any document against the plugin's capabilities; reports what converts directly, what needs changes, and what's out of scope |
| `fixture-format` | Defines the standardized JSON fixture file format shared across all generators |
| `debugging-scenarios` | Guides troubleshooting when generated tests fail — iframe detection, selector drift, timing, stale fixtures |

## Host Project Setup

The plugin is designed for a JVM project using Gradle, Kotest, and Playwright for Java. Before the commands will work end-to-end, the host project needs the following in place.

### 1. Dependencies

In `build.gradle.kts` (use current versions — these are illustrative):

```kotlin
dependencies {
    testImplementation("com.microsoft.playwright:playwright:1.47.0")
    testImplementation("io.kotest:kotest-runner-junit5:5.9.1")
}
```

### 2. Gradle tasks: browser install + recording

`/record-scenario` invokes a Gradle `recordScenario` task to launch Playwright codegen. Playwright for Java doesn't bundle browsers, so you also need a one-time task to download them. Add both to `build.gradle.kts`:

```kotlin
tasks.register<JavaExec>("installPlaywrightBrowsers") {
    description = "Download Playwright browser binaries (one-time setup)."
    group = "verification"
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("com.microsoft.playwright.CLI")
    args = listOf("install")
}

tasks.register<JavaExec>("recordScenario") {
    description = "Launch Playwright codegen to record a browser flow as a Java file."
    group = "verification"

    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("com.microsoft.playwright.CLI")

    doFirst {
        val url = project.findProperty("url") as String? ?: error("Provide -Purl=<start-url>")
        val out = project.findProperty("out") as String? ?: error("Provide -Pout=<output-path>")
        args = listOf("codegen", "--target", "java", "-o", out, url)
        file(out).parentFile?.mkdirs()
    }
}
```

Run the install task once after adding the Playwright dependency:

```
./gradlew installPlaywrightBrowsers
```

### 3. `playwright-cli` (for `/review-scenario`, `/scenario-to-tests`, and `/crawl-site`)

These three commands use the `playwright-cli` skill during their live-site exploration phase, which shells out to the `playwright-cli` binary. Install it globally:

```
npm install -g @playwright/cli@latest
```

Or verify a local copy via `npx`:

```
npx --no-install playwright-cli --version
```

If `npx playwright-cli --version` works, the commands will fall back to `npx playwright-cli` automatically — no global install needed.

`/record-scenario` does not use `playwright-cli`; it launches Playwright codegen via the Gradle `recordScenario` task, so this step can be skipped if you only plan to record.

### 4. Scenario directory

Scenario markdown files live in the project's configured scenario directory (`scenario_dir` in `.claude/playwright-scenarios.local.md`). The default is `src/test/scenarios/`. The first time you run any plugin command, the bootstrap creates three command-keyed subdirectories under it:

- `<scenario_dir>/record/` — written to by `/record-scenario`
- `<scenario_dir>/crawl/` — written to by `/crawl-site`
- `<scenario_dir>/convert/` — written to by `/doc-to-scenarios`

There is no draft step. The scenario in its partition is the canonical artifact. If you want to hand-edit or delete a scenario before review, do it in place, then run `/review-scenario`.

### 5. A base test class

For the Kotlin + Kotest default, `/scenario-to-tests` generates tests that extend a project-provided base class (typically `BasePageTest`) which owns the Playwright browser lifecycle. The first time you run any plugin command you'll be asked where to emit these tests (`test_dir`); that path is saved to `.claude/playwright-scenarios.local.md` and reused thereafter. If your project doesn't have a base test class yet, a minimal starting point:

```kotlin
package com.example.qa.examples

import com.microsoft.playwright.*
import io.kotest.core.spec.style.StringSpec

abstract class BasePageTest : StringSpec() {
    private val playwright = Playwright.create()
    protected val browser: Browser = playwright.chromium().launch()
    protected lateinit var page: Page

    init {
        beforeTest {
            page = browser.newContext().newPage()
        }
        afterTest {
            page.context().close()
        }
        finalizeSpec { playwright.close() }
    }
}
```

Place it wherever your existing test support classes live.

## Configuration

Per-project settings are stored in `.claude/playwright-scenarios.local.md` (YAML frontmatter + markdown body). The first time you run any `playwright-scenarios` command, you'll be prompted for each field and the file will be created for you. To re-prompt later, run `/playwright-scenarios-config`.

```markdown
---
scenario_dir: src/test/scenarios
test_dir: src/test/kotlin/com/example/qa/scenarios
test_language: kotlin
test_framework: kotest-stringspec
---
```

| Field | Required? | Default | Purpose |
|-------|-----------|---------|---------|
| `scenario_dir` | yes | `src/test/scenarios` | Where scenario markdown files live (relative to repo root). |
| `test_dir` | yes | prompted | Where generated test files go (relative to repo root). |
| `test_language` | yes | `kotlin` | Target language for generated tests. |
| `test_framework` | yes | `kotest-stringspec` | Target framework for generated tests. |
| `source_root` | optional | inferred from `test_dir` | Source-set root above the test package (e.g. `src/test/kotlin`). Set this explicitly if `/scenario-to-tests` reports it couldn't infer the source root from your `test_dir`. |
| `base_test_class` | optional | auto-detected | Fully-qualified name of the class generated tests should extend. Auto-detected on first run and persisted; set explicitly if multiple candidates exist or none are found. |

**Currently supported combinations for `/scenario-to-tests`:** `kotlin` + `kotest-stringspec` only. Other values for `test_language` / `test_framework` are accepted and persisted but `/scenario-to-tests` will abort with a clear message until generation rules for that stack are added.

The four required fields must all be present and non-empty. If the file is malformed, commands abort with a pointer to `/playwright-scenarios-config`, which has a dedicated recovery path that shows the broken content and offers to overwrite.

The file is checked into git by default so contributors share the same layout. Add it to `.gitignore` if you prefer per-user settings.

## Documentation

For detailed guides — terminology, workflow, the full command and skill reference, capabilities, writing effective docs, and troubleshooting — see the [project website](website/playwright-scenarios/docs/index.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT — see [LICENSE](LICENSE).
