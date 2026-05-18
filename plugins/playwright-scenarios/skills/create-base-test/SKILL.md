---
name: create-base-test
description: Create a Kotlin BasePageTest class into the consuming project so generated tests have something to extend. Currently supports kotlin + kotest-stringspec only. Invoked by /create-base-test (explicit) and by loading-config (auto-offered when zero base-test-class candidates are found in the project). Owns three customization prompts (`/reset` endpoint, lifecycle scope, browser) and writes a single .kt file inside <TEST_DIR>.
---

# Create Base Test

## When this skill is invoked

- **Explicitly** by `/create-base-test`.
- **Automatically** by `loading-config`'s base-test-class discovery when zero candidates are found.

## Inputs from caller

- **`<TEST_LANGUAGE>`** — must be `kotlin`.
- **`<TEST_FRAMEWORK>`** — must be `kotest-stringspec`.
- **`<TEST_DIR>`** — the configured test directory (e.g., `src/test/kotlin/com/example/qa/scenarios`).
- **`<SOURCE_ROOT>`** — the source-set root (e.g., `src/test/kotlin`). Resolved by the caller via `loading-config`'s source-root inference.

## Procedure

### 1. Guard on language/framework

If `<TEST_LANGUAGE>` ≠ `kotlin` or `<TEST_FRAMEWORK>` ≠ `kotest-stringspec`, return the structured error `UNSUPPORTED_COMBO: <TEST_LANGUAGE> + <TEST_FRAMEWORK>` to the caller and stop. The caller owns the user-facing message; this skill never writes a file in this state.

### 2. Resolve target file path and package

The base class goes **inside `<TEST_DIR>`** — sibling to the `crawl/`, `record/`, and `convert/` subfolders, in the package that matches `<TEST_DIR>`. The reference layout is `src/test/kotlin/com/example/qa/scenarios/BasePageTest.kt` (package `com.example.qa.scenarios`) paired with `src/test/kotlin/com/example/qa/scenarios/{crawl,record,convert}/` (packages `com.example.qa.scenarios.crawl`, etc.). The playwright-scenarios-kotlin-template uses an analogous layout under `src/test/kotlin/com/bookshelf/scenarios/`.

Compute:

- `target_file` = `<TEST_DIR>/BasePageTest.kt`.
- `package_name` = `<TEST_DIR>` with the `<SOURCE_ROOT>` prefix stripped, leading/trailing `/` removed, `/` replaced by `.` (e.g., `com.example.qa.scenarios`). Empty if `<TEST_DIR> == <SOURCE_ROOT>`.
- `fqn` = `<package_name>.BasePageTest`, or just `BasePageTest` if `package_name` is empty.

If stripping `<SOURCE_ROOT>` doesn't yield a clean prefix match (shouldn't happen if `loading-config` resolved the source root correctly, but defend), prompt with `AskUserQuestion`: "Couldn't derive a package from `<TEST_DIR>` and `<SOURCE_ROOT>`. Where should `BasePageTest.kt` go?" with the inferred path, the source root, and "Other".

If `target_file` already exists on disk, return `TARGET_EXISTS: <target_file>` to the caller and stop. Never overwrite.

Show the resolved `target_file` and `fqn` to the user before prompting for customizations.

### 3. Run the three customization prompts

Issue a single `AskUserQuestion` call with three single-select questions:

1. **Reset endpoint** — "Does your dev server expose a `POST /reset` endpoint that resets state between specs? Most dev servers don't — this is a deliberate test affordance that purpose-built fixture or demo apps add for predictable state."
   - `No (Recommended)` — omit `resetServerState()` and its imports.
   - `Yes` — emit `resetServerState()` and call it from the lifecycle hook.

2. **Lifecycle** — "Run the browser lifecycle once per spec class, or once per test?"
   - `Per spec (Recommended)` — `beforeSpec` / `afterSpec`. Faster; tests share state within a spec.
   - `Per test` — `beforeTest` / `afterTest`. Slower; full isolation.

3. **Browser** — "Which Playwright browser should tests launch?"
   - `Chromium (Recommended)`, `Firefox`, or `Webkit`.

Normalize each answer by stripping the trailing ` (Recommended)`. Variant rules below reference the canonical values: reset ∈ {`Yes`, `No`}, lifecycle ∈ {`Per spec`, `Per test`}, browser ∈ {`Chromium`, `Firefox`, `Webkit`}.

### 4. Render the template

Start from the canonical template below (matches `Yes`, `Per spec`, `Chromium`) and apply variant rules.

#### Canonical template

```kotlin
package {{PACKAGE_NAME}}

import com.microsoft.playwright.Browser
import com.microsoft.playwright.BrowserContext
import com.microsoft.playwright.BrowserType
import com.microsoft.playwright.Page
import com.microsoft.playwright.Playwright
import io.kotest.core.spec.Spec
import io.kotest.core.spec.style.StringSpec
import java.net.HttpURLConnection
import java.net.URI

abstract class BasePageTest : StringSpec() {
  protected lateinit var playwright: Playwright
  protected lateinit var browser: Browser
  protected lateinit var context: BrowserContext
  protected lateinit var page: Page

  protected open val baseUrl: String = "http://localhost:8080"

  override suspend fun beforeSpec(spec: Spec) {
    resetServerState()
    val headless = System.getProperty("playwright.headless", "true").toBoolean()
    playwright = Playwright.create()
    browser = playwright.chromium().launch(
      BrowserType.LaunchOptions().setHeadless(headless)
    )
    context = browser.newContext(
      Browser.NewContextOptions().setBaseURL(baseUrl)
    )
    page = context.newPage()
  }

  private fun resetServerState() {
    val connection = URI("$baseUrl/reset").toURL().openConnection() as HttpURLConnection
    try {
      connection.requestMethod = "POST"
      connection.instanceFollowRedirects = false
      connection.connectTimeout = 2_000
      connection.readTimeout = 2_000
      connection.responseCode
    } finally {
      connection.disconnect()
    }
  }

  override suspend fun afterSpec(spec: Spec) {
    if (::context.isInitialized) context.close()
    if (::browser.isInitialized) browser.close()
    if (::playwright.isInitialized) playwright.close()
  }
}
```

Substitute `{{PACKAGE_NAME}}` with `package_name` from step 2. If `package_name` is empty, drop the entire `package` line and the blank line beneath it.

#### Variant rules

Apply rules in any order. Imports stay alphabetically sorted in a single flat block.

**reset = `No`**

- Drop the `import java.net.HttpURLConnection` and `import java.net.URI` lines.
- Drop the `resetServerState()` call inside the lifecycle hook.
- Drop the entire `private fun resetServerState() { ... }` block.

**lifecycle = `Per test`**

Splits the lifecycle so the expensive `Playwright` and `Browser` are created once per spec, while the cheap `BrowserContext` and `Page` are recreated per test for isolation. Without this split, every test would spin up a fresh JVM-side Playwright driver — typically a 5–10× slowdown vs. per-spec.

- **Imports:** keep `io.kotest.core.spec.Spec`. Add `io.kotest.core.test.TestCase` and `io.kotest.core.test.TestResult` (alphabetically sorted within the import block).
- **`beforeSpec` body:** keep only the `headless` lookup, `playwright = Playwright.create()`, and `browser = playwright.chromium().launch(...)` lines. Drop the `resetServerState()` call, the `context = browser.newContext(...)` line, and the `page = context.newPage()` line.
- **Add `beforeTest`** immediately after `beforeSpec`:
  ```kotlin
  override suspend fun beforeTest(testCase: TestCase) {
    resetServerState()
    context = browser.newContext(
      Browser.NewContextOptions().setBaseURL(baseUrl)
    )
    page = context.newPage()
  }
  ```
  If reset = `No`, drop the `resetServerState()` line.
- **`afterSpec` body:** keep only the `browser` and `playwright` close lines. Drop the `context` close line.
- **Add `afterTest`** immediately after `afterSpec`:
  ```kotlin
  override suspend fun afterTest(testCase: TestCase, result: TestResult) {
    if (::context.isInitialized) context.close()
  }
  ```

**browser = `Firefox`** — replace `playwright.chromium()` with `playwright.firefox()`.

**browser = `Webkit`** — replace `playwright.chromium()` with `playwright.webkit()`.

### 5. Write the file

Write `target_file` with the rendered content. Create intermediate package directories as needed.

### 6. Return to caller

Return `{fqn, target_file, choices: {reset, lifecycle, browser}}`. The caller persists `base_test_class` to `.claude/playwright-scenarios.local.md`; this skill never edits the config.

### 7. Closing report

Print:

```
Created BasePageTest at <target_file>
  Package: <package_name> (FQN: <fqn>)
  Reset endpoint: <Yes|No>
  Lifecycle: <Per spec|Per test>
  Browser: <Chromium|Firefox|Webkit>
```

Then direct the user to their next step: authoring a scenario for `/scenario-to-tests` to turn into tests. Tell them to pick one of the three authoring commands:

- `/crawl-site <url>` — **crawl** a site to discover user flows.
- `/record-scenario <url>` — **record** a flow by driving a browser.
- `/doc-to-scenarios <path>` — **convert** a written document into scenarios.

## What this skill does NOT do

- Does not write to `.claude/playwright-scenarios.local.md` — the caller persists `base_test_class`.
- Does not overwrite an existing `BasePageTest.kt` — `TARGET_EXISTS` is returned instead.
- Does not support combinations other than `kotlin` + `kotest-stringspec`. When `/scenario-to-tests` grows generation paths for additional stacks, matching template variants will land here.
