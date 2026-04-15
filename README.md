# playwright-scenarios

Claude Code marketplace for scenario-driven Playwright testing — record scenarios by driving a browser, audit them against the live site, and generate JVM Playwright + Kotest tests from the reviewed markdown.

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
| `/record-scenario [name]` | Launch Playwright codegen, capture a real user flow, and write a draft scenario markdown file to the configured scenario directory |
| `/review-scenario [names...]` | Audit scenarios against the live site and apply improvements to the markdown |
| `/scenario-to-tests [names...]` | Generate tests (defaults: Kotlin + Kotest StringSpec with Playwright-for-Java) from reviewed scenarios |
| `/playwright-scenarios-config` | View or update per-project settings in `.claude/playwright-scenarios.local.md` |

**Skills**

| Skill | Description |
|-------|-------------|
| `loading-config` | Reads `.claude/playwright-scenarios.local.md` and bootstraps it on first use; invoked automatically at the start of every command |
| `authoring-scenarios` | Flat-markdown format reference used whenever Claude hand-writes or edits a scenario markdown file |

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

### 3. Scenario directory

Scenario markdown files live in the project's configured scenario directory (`scenario_dir` in `.claude/playwright-scenarios.local.md`). The default is `src/test/scenarios/`; `scenarios/` at the repo root is offered as a legacy alternative. You don't need to create the directory by hand — the first time you run `/record-scenario` the plugin will prompt you to pick a location and create it on demand.

Work-in-progress scenarios can go in a `drafts/` subdirectory (e.g. `src/test/scenarios/drafts/`). `/review-scenario` and `/scenario-to-tests` skip files under subdirectories unless they're named explicitly.

### 4. A base test class

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

| Field | Default | Purpose |
|-------|---------|---------|
| `scenario_dir` | `src/test/scenarios` | Where scenario markdown files live (relative to repo root). |
| `test_dir` | prompted | Where generated test files go (relative to repo root). |
| `test_language` | `kotlin` | Target language for generated tests. |
| `test_framework` | `kotest-stringspec` | Target framework for generated tests. |

**Currently supported combinations for `/scenario-to-tests`:** `kotlin` + `kotest-stringspec` only. Other values for `test_language` / `test_framework` are accepted and persisted but `/scenario-to-tests` will abort with a clear message until generation rules for that stack are added.

The file is checked into git by default so contributors share the same layout. Add it to `.gitignore` if you prefer per-user settings.

## Workflow

1. **Record**: `/record-scenario checkout-flow` opens a browser, you demonstrate the flow, and a draft `<scenario_dir>/checkout-flow.md` is written.
2. **Review**: `/review-scenario checkout-flow` validates the scenario's claims against the live site and rewrites the markdown in place.
3. **Generate**: `/scenario-to-tests checkout-flow` emits a scenario test file in `<test_dir>` (e.g. `src/test/kotlin/com/example/qa/scenarios/CheckoutFlowTest.kt`).

Scenarios use a flat markdown format (`# Title`, `**URL:** /path`, numbered `## Test N:` blocks with `- **Action:**` / `- **Expected:**` bullets). Generated tests extend your project's base test class, which owns the Playwright browser lifecycle.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT — see [LICENSE](LICENSE).
