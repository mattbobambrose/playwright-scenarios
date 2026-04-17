---
icon: lucide/graduation-cap
---

# Tutorial

A hands-on walkthrough of the full plugin workflow. By the end, you'll have installed the plugin, configured it for your project, written a scenario, reviewed it against the live site, and generated executable test code.

## 1. Install the plugin

Add the marketplace and install the plugin:

```
/plugin marketplace add mattbobambrose/playwright-scenarios
/plugin install playwright-scenarios@playwright-scenarios
```

Verify it's installed — you should see the commands when you type `/`:

```
/record-scenario
/crawl-site
/review-scenario
/scenario-to-tests
/playwright-scenarios-config
/spec-to-scenarios
/generate-fixture
/scenario-status
```

## 2. Set up your host project

The plugin generates tests for your project, so it needs a few things in place. If you're using the default Kotlin + Kotest stack, add to your `build.gradle.kts`:

```kotlin
dependencies {
    testImplementation("com.microsoft.playwright:playwright:1.47.0")
    testImplementation("io.kotest:kotest-runner-junit5:5.9.1")
}
```

Add the Gradle tasks for browser install and recording:

```kotlin
tasks.register<JavaExec>("installPlaywrightBrowsers") {
    description = "Download Playwright browser binaries (one-time setup)."
    group = "verification"
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("com.microsoft.playwright.CLI")
    args = listOf("install")
}

tasks.register<JavaExec>("recordScenario") {
    description = "Launch Playwright codegen to record a browser flow."
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

Download the browsers (one-time):

```
./gradlew installPlaywrightBrowsers
```

Install `playwright-cli` for the review and crawl commands:

```
npm install -g @playwright/cli@latest
```

## 3. Configure the plugin

The first time you run any plugin command, it prompts you for four settings. You can also trigger this explicitly:

```
/playwright-scenarios-config
```

You'll be asked:

1. **Where should scenario files live?** — Default: `src/test/scenarios`
2. **Where should generated tests go?** — e.g., `src/test/kotlin/com/example/bookstore/scenarios`
3. **What language?** — Playwright supports five languages:

    | Language | Playwright binding |
    |----------|--------------------|
    | Java | `com.microsoft.playwright` |
    | Kotlin | `com.microsoft.playwright` (same Java binding) |
    | Python | `playwright` (pip) |
    | JavaScript | `@playwright/test` (npm) |
    | TypeScript | `@playwright/test` (npm) |
    | .NET | `Microsoft.Playwright` (NuGet) |

4. **What test framework?** — Options depend on the language you chose:

    | Language | Framework options |
    |----------|-------------------|
    | Kotlin | `kotest-stringspec` (default), `junit5` |
    | Java | `junit5` |
    | TypeScript | `playwright-test` (default), `jest` |
    | JavaScript | `playwright-test` (default), `jest` |
    | Python | `pytest` |
    | .NET | `nunit`, `mstest` |

!!! warning "Current support"
    Test generation is fully wired for **Kotlin + Kotest StringSpec** only. Other language/framework combinations are accepted and saved to your config, but `/scenario-to-tests` will report an unsupported-combination message until their generation rules are added.

The answers are saved to `.claude/playwright-scenarios.local.md` and reused for every command. You can re-run `/playwright-scenarios-config` anytime to change them.

## 4. Write your first scenario

Create a file at `src/test/scenarios/search-for-book.md`:

```markdown
# Search For Book

**URL:** https://bookstore.example.com

Search for a book by title and verify the results page.

## Test 1: Search returns matching results

- **Action:** Enter 'The Great Gatsby' into the 'Search books' field.
- **Action:** Click the 'Search' button.
- **Expected:** The URL changes to /books?q=The+Great+Gatsby.
- **Expected:** The heading 'Search results for "The Great Gatsby"' is visible.
- **Expected:** At least one product card is visible.

## Test 2: Click a search result

- **Action:** Click the first product card link.
- **Expected:** The heading 'The Great Gatsby' is visible.
- **Expected:** The text 'F. Scott Fitzgerald' is visible.
- **Expected:** A button labeled 'Add to Cart' is visible.
```

!!! tip "Format rules"
    - **Actions** use imperative voice: "Click...", "Enter...", "Scroll..."
    - **Expected** uses descriptive voice: "The heading is visible", "The URL changes to..."
    - Use exact DOM text: `'Search books'` not "the search box"
    - Every test case needs at least one Action and one Expected

## 5. Review against the live site

```
/review-scenario search-for-book
```

This opens the URL in a browser, walks through each test case, and checks whether the scenario's claims match reality. It will:

- **Fix broken claims** — if the search field is actually labeled `'Search for books...'` instead of `'Search books'`, it rewrites the selector
- **Tighten vague assertions** — if you wrote "results appear," it rewrites to "The heading 'Search results for...' is visible"
- **Flag missing coverage** — if there's an obvious empty-state case you didn't cover, it suggests adding a test

After review, your scenario file is rewritten in place with the fixes applied. You'll see a summary table of what changed.

## 6. Generate tests

```
/scenario-to-tests search-for-book
```

This generates a Kotlin test file at `src/test/kotlin/com/example/bookstore/scenarios/SearchForBookTest.kt`:

```kotlin
class SearchForBookTest : BasePageTest() {
    init {
        "Search returns matching results" {
            page.navigate("https://bookstore.example.com")
            page.getByLabel("Search books").fill("The Great Gatsby")
            page.getByRole(AriaRole.BUTTON, Page.GetByRoleOptions().setName("Search")).click()
            page.waitForURL("**/books?q=The+Great+Gatsby")
            assertThat(page.getByRole(AriaRole.HEADING, Page.GetByRoleOptions()
                .setName("Search results for \"The Great Gatsby\""))).isVisible()
        }

        "Click a search result" {
            // ...
        }
    }
}
```

The command then runs `./gradlew test --tests "*.SearchForBookTest"` and reports pass/fail. If tests fail, it fixes them and re-runs.

## 7. Try recording instead

Instead of hand-writing a scenario, you can record one by driving a browser:

```
/record-scenario add-to-cart
```

1. You'll be asked for a start URL.
2. A Chromium window opens with the Playwright Inspector.
3. Browse the site normally — click links, fill forms, navigate pages.
4. Use the Inspector toolbar to mark assertions (assert visibility, assert text, assert value).
5. Close the browser when done.

The plugin converts your recording into a scenario file and automatically runs `/review-scenario` on it.

## 8. Use extended tags

Once you're comfortable with the basics, tags let you handle more complex testing patterns.

### Fixtures for shared test data

Instead of repeating the same customer details across scenarios, create a fixture:

```
/generate-fixture interactive --name=returning-customer
```

Then reference it in your scenario:

```markdown
# Checkout Happy Path

**URL:** https://bookstore.example.com/checkout
**Fixture:** fixtures/returning-customer

## Test 1: Pre-filled shipping address

- **Expected:** The 'Address' field contains '123 Main St'.
- **Expected:** The 'City' field contains 'Portland'.
```

### Iframes for embedded content

If your checkout uses a Stripe payment form in an iframe:

```markdown
# Payment Flow

**URL:** https://bookstore.example.com/checkout
**Iframe:** #stripe-payment-iframe

## Test 1: Enter card details

- **Action:** Enter '4242424242424242' into the 'Card number' field.
- **Action:** Click the 'Pay now' button.
- **Expected:** The heading 'Order confirmed' is visible.

## Test 2: View confirmation (outside iframe)

**Iframe:** none

- **Expected:** The heading 'Thank you for your order' is visible.
```

### Branches for alternate paths

Test a different path using the same fixture with one field overridden:

```markdown
# International Shipping Surcharge

**URL:** https://bookstore.example.com/checkout
**Fixture:** fixtures/returning-customer
**Branch:** shipping.country = CA

## Test 1: Surcharge applied

- **Action:** Select 'Canada' from the 'Country' dropdown.
- **Action:** Click the 'Calculate Shipping' button.
- **Expected:** The text 'International shipping surcharge: $12.99' is visible.
```

### Known bugs as regression guards

```markdown
## Test 3: Discount code error message

- **Expected failure:** Copy bug — missing "is" in error message
- **Action:** Enter 'INVALID' into the 'Discount code' field.
- **Action:** Click 'Apply'.
- **Expected:** Error reads "This discount code is not valid."
```

When the bug is fixed, this test flips from "expected failure" to real failure, signaling the guard can be removed.

### Mocking network requests

Test error states that can't be triggered through the UI:

```markdown
## Test 4: API failure shows error page

- **Intercept:** **/api/checkout → 500
- **Action:** Click the 'Place Order' button.
- **Expected:** The heading 'Something went wrong' is visible.
- **Expected:** A button labeled 'Try Again' is visible.
```

## 9. Crawl a site for coverage

If you're not sure what flows to test, let the plugin discover them:

```
/crawl-site https://bookstore.example.com
```

This navigates the site (read-only — never fills forms or clicks destructive buttons), identifies user flows grouped by type (navigation, hero CTAs, auth gates, footer), and writes draft scenarios to `src/test/scenarios/drafts/`.

Review the drafts and promote the ones you want to keep:

```bash
# Look at what was generated
ls src/test/scenarios/drafts/

# Promote a draft
mv src/test/scenarios/drafts/nav-to-bestsellers.md src/test/scenarios/nav-to-bestsellers.md

# Review and generate
/review-scenario nav-to-bestsellers
/scenario-to-tests nav-to-bestsellers
```

## 10. Convert existing specs

If you have a QA spec or test plan document, evaluate it first:

Ask Claude to evaluate your spec — the `evaluate-spec` skill classifies each test case as direct (converts cleanly), needs changes (fixable), or out of scope (needs a different tool).

Then convert:

```
/spec-to-scenarios path/to/checkout-spec.md
```

!!! tip "Write better specs upfront"
    If you're using an LLM to generate specs, paste [SPEC_GUIDE.md](https://github.com/mattbobambrose/playwright-scenarios/blob/master/plugins/playwright-scenarios/SPEC_GUIDE.md) into its context first. The LLM will follow the rules and produce clean output that needs minimal evaluation.

## 11. Monitor health

Once you have several scenarios and generated tests, check the dashboard:

```
/scenario-status
```

This shows:

- Which scenarios have been reviewed recently
- Which test files are stale (scenario changed since tests were generated)
- Pass/fail status from the latest test run
- Coverage gaps vs. the crawl inventory

## What's next

- Read the [Terminology](terminology.md) page to make sure you're using terms consistently
- Study the [Workflow](workflow.md) page to understand all four paths to reviewed scenarios
- Check [Capabilities](capabilities.md) for the full list of what the plugin can and can't test
- See [Writing Specs](writing-specs.md) for guidance on writing specs that convert cleanly

## All 13 tags at a glance

| Tag | What it does |
|-----|-------------|
| `**Fixture:**` | Load shared test data from a JSON file |
| `**Branch:**` | Override one fixture field for an alternate path |
| `**Prerequisite:**` | Run another scenario as setup first |
| `**Assert throughout:**` | Check an invariant across the entire flow |
| `**Iframe:**` | Target content inside an iframe |
| `**Expected failure:**` | Mark a test as a known-bug regression guard |
| `**Expected (regex):**` | Regex match for variable content |
| `**Intercept:**` | Mock a network request |
| `**Cookie:**` | Pre-set a cookie before the flow starts |
| `**Storage:**` | Pre-set localStorage before the flow starts |
| `**Device:**` | Emulate a device (viewport + user-agent) |
| `**Timeout:**` | Override the test timeout |
| `**Cleanup:**` | Run a teardown action after the test |
