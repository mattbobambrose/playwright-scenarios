---
icon: lucide/life-buoy
---

# Troubleshooting

Setup-time and operational failures, with a fix for each.

!!! info "Looking for test-failure debugging?"
    If a *generated* test is broken — wrong selector, race condition, iframe issue, missing fixture data — that's covered by the `debugging-scenarios` skill, not this page. Ask Claude something like *"the SearchForBookTest is failing — debug it"* and the skill activates.

---

## Plugin install & command discovery

### Marketplace add succeeded but commands don't appear

> **Symptom:** You ran `/plugin marketplace add mattbobambrose/playwright-scenarios` and `/plugin install playwright-scenarios@playwright-scenarios`, but typing `/` in Claude Code doesn't show `/record-scenario`, `/crawl-site`, etc.<br>
> **Cause:** The install often takes effect on the next session, or the plugin is installed but not enabled.<br>
> **Fix:** Quit Claude Code and relaunch with `claude`. If commands still don't appear, run `/plugin` and confirm `playwright-scenarios` is listed and enabled.

### `/plugin install` fails

> **Symptom:** Install errors out with a not-found or auth error.<br>
> **Cause:** Either the marketplace name is wrong (it must be `mattbobambrose/playwright-scenarios`, not `playwright-scenarios` alone), or there is no network reachability to GitHub.<br>
> **Fix:** Re-run with the full marketplace path. If GitHub is reachable in a browser but not from Claude, check any corporate proxy / VPN settings.

### Commands appear but error immediately on first run

> **Symptom:** `/record-scenario` (or any other command) errors out before doing anything.<br>
> **Cause:** Almost always a config-bootstrap problem — `.claude/playwright-scenarios.local.md` is missing, malformed, or has a required field blank.<br>
> **Fix:** Run `/playwright-scenarios-config`. See [Config](#config) below for the specific symptoms it handles.

---

## Config

(File: `.claude/playwright-scenarios.local.md`)

### `MALFORMED_CONFIG: …` returned by every command

> **Symptom:** Every plugin command aborts with a message like "MALFORMED_CONFIG: test_language is missing" and tells you to run `/playwright-scenarios-config`.<br>
> **Cause:** The config file exists but a required field (`scenario_dir`, `test_dir`, `test_language`, `test_framework`) is missing, blank, or the YAML doesn't parse.<br>
> **Fix:** Run `/playwright-scenarios-config`. It detects the problem, prints the offending content, and offers to overwrite with a fresh interactive bootstrap. If you'd rather edit the file by hand, the four required fields must each have a non-empty value, all wrapped in `---` fences.

### Wrong language or framework saved on first bootstrap

> **Symptom:** You answered the bootstrap questions too quickly and `test_language` or `test_framework` is now wrong.<br>
> **Cause:** Bootstrap only runs the first time — every subsequent command reuses the saved config.<br>
> **Fix:** Run `/playwright-scenarios-config` and select the field to change. The command shows current values in a table and lets you update any one of them.

### `base_test_class` auto-inference picked the wrong class

> **Symptom:** `/scenario-to-tests` generates files that extend the wrong base class.<br>
> **Cause:** The auto-inference walks your test source tree and picks the first base test class it finds. In a multi-module project this isn't always the right one.<br>
> **Fix:** Open `.claude/playwright-scenarios.local.md` and add (or correct) `base_test_class: com.example.path.ToYourBaseClass`. Re-run `/scenario-to-tests`.

### No base test class exists in the project

> **Symptom:** Generated tests have no `extends` clause and a TODO comment at the top of every file. Or `loading-config` warned during bootstrap that no base class was found and you said "No" to the offer to create one.<br>
> **Cause:** The host project doesn't yet define a Playwright + Kotest base class.<br>
> **Fix:** Run `/create-base-test`. It prompts for three customizations (whether the dev server has a `POST /reset` endpoint, whether the browser lifecycle runs per-spec or per-test, and which Playwright browser to launch), writes a `BasePageTest.kt` inside `<test_dir>` (sibling to the subfolders), and persists the FQN to `base_test_class`. Re-run `/scenario-to-tests` afterwards — generated tests will now extend the new class.

### "Couldn't infer the source root from `test_dir=…`"

> **Symptom:** A command aborts with that exact message.<br>
> **Cause:** Your `test_dir` doesn't match a recognized layout (e.g., it's not under `src/test/<lang>/` and not under `tests/`).<br>
> **Fix:** Add `source_root: <your-source-root>` to `.claude/playwright-scenarios.local.md` and retry. The source root is the directory containing your project's source-language packages (e.g., `src/main/kotlin`, `app/src`, etc.).

### "I want to use this in a project with no build file yet"

> **Symptom:** Bootstrap completes, but `/scenario-to-tests` writes Kotlin files that have nowhere to compile.<br>
> **Cause:** The plugin needs a host project that can run the generated tests. It does not create the project for you.<br>
> **Fix:** Clone one of the language template repos linked from the [Tutorial](tutorial.md) — they include the build configuration you need. Then run `/playwright-scenarios-config` to point the plugin at the new layout.

---

## `playwright-cli` (used by `/review-scenario` and `/crawl-site`)

### "playwright-cli is not available"

> **Symptom:** `/review-scenario` or `/crawl-site` aborts in preflight with a message asking you to install `playwright-cli`.<br>
> **Cause:** The skill checks `playwright-cli --version` first, then `npx --no-install playwright-cli --version`. If both fail, it stops before doing any work.<br>
> **Fix:** `npm install -g @playwright/cli@latest`. If you can't install globally, ensure `npx playwright-cli` works from your project root (i.e., it's a dev dependency).

### `npm install -g` fails with EACCES

> **Symptom:** `npm install -g @playwright/cli@latest` errors out with permission-denied messages.<br>
> **Cause:** The default global npm prefix is owned by root.<br>
> **Fix:** Either run with `sudo`, or (better) configure npm to use a user-writable prefix: `npm config set prefix ~/.npm-global` and add `~/.npm-global/bin` to your `PATH`. Re-run the install.

### `npm install` fails because Node is too old

> **Symptom:** Install fails with an EBADENGINE warning about Node version.<br>
> **Cause:** `@playwright/cli` requires a recent Node release.<br>
> **Fix:** Upgrade Node (e.g., via `nvm install --lts`) and retry.

### macOS Gatekeeper blocks the browser binary on first launch

> **Symptom:** First call to `/review-scenario` opens a Gatekeeper dialog about an unverified binary, then the command stalls.<br>
> **Cause:** macOS quarantines downloaded Playwright browser binaries.<br>
> **Fix:** Approve the binary in **System Settings → Privacy & Security**, then re-run.

---

## Browser binaries & recording tasks

### "recordScenario task not found" or "Could not find Playwright"

> **Symptom:** `/record-scenario` aborts saying the Gradle task is missing.<br>
> **Cause:** The host project doesn't define the `recordScenario` task. The plugin doesn't add it for you.<br>
> **Fix:** These tasks are provided pre-configured by the language template repos linked from the [Tutorial](tutorial.md). Use a template repo, or add the `recordScenario` and `installPlaywrightBrowsers` tasks to your `build.gradle.kts` by hand.

### Browsers won't download

> **Symptom:** `./gradlew installPlaywrightBrowsers` hangs or fails on download.<br>
> **Cause:** Corporate proxy or firewall blocks Playwright's CDN.<br>
> **Fix:** Set `HTTPS_PROXY` / `HTTP_PROXY` environment variables before re-running, or pre-fetch the binaries on a permitted machine and copy them to `~/Library/Caches/ms-playwright` (macOS) / `~/.cache/ms-playwright` (Linux).

### Headed mode won't open a window

> **Symptom:** `/record-scenario` reports a started browser but no window appears (or opens and immediately closes).<br>
> **Cause:** No display server — common on Linux without X, WSL without WSLg, or remote SSH without forwarding.<br>
> **Fix:** Run on a machine with a display, enable WSLg / X-forwarding, or use `/crawl-site` (headless) instead. `/record-scenario` requires a real interactive browser.

---

## Host project (Kotlin path)

### Generated test won't compile

> **Symptom:** `/scenario-to-tests` writes a file but `./gradlew test` fails with unresolved references.<br>
> **Cause:** Either the Kotest/Playwright-for-Java dependencies aren't on the test classpath, or the base test class is in a different package than the generated file.<br>
> **Fix:** Confirm Kotest and Playwright-for-Java are on the test classpath (the template repos linked from the [Tutorial](tutorial.md) include them). If the base class is in a different package, set `base_test_class` in `.claude/playwright-scenarios.local.md` and `test_dir` to the matching package directory.

### Generated test compiles but the runner can't find it

> **Symptom:** `./gradlew test --tests "*.SearchForBookTest"` reports zero tests found.<br>
> **Cause:** Kotest needs the JUnit 5 runner. Without `kotest-runner-junit5`, Gradle can't discover the test.<br>
> **Fix:** Add `testImplementation("io.kotest:kotest-runner-junit5")` (latest 5.x) and `useJUnitPlatform()` inside your `tasks.test { … }` block.

---

## Non-Kotlin stacks

### "Unsupported language/framework combination"

> **Symptom:** `/scenario-to-tests` writes nothing and reports the combination is unsupported.<br>
> **Cause:** Test generation is fully wired only for Kotlin + Kotest StringSpec. Other combinations bootstrap and save fine but the generator hasn't landed yet.<br>
> **Fix:** Either change `test_language` / `test_framework` to `kotlin` / `kotest-stringspec` (via `/playwright-scenarios-config`), or wait for the generator for your stack to be added. Scenarios you author now will be reusable when it lands — the markdown format is generator-agnostic.

---

## `/crawl-site` results

### Crawl finishes but writes no scenarios

> **Symptom:** `/crawl-site` reports completion with an empty `<scenario_dir>/crawl/` directory.<br>
> **Cause #1:** The start page is JS-rendered and links don't exist in the initial HTML the crawler sees.<br>
> **Fix:** The crawler sees what `playwright-cli snapshot` returns after the page loads — if links only appear after a client-side route change, the crawl can't follow them. Use `/record-scenario` for those flows instead, or point the crawl at a server-rendered route.

> **Cause #2:** Your description filtered everything out (e.g., "focus on checkout" on a site with no recognizable checkout flow).<br>
> **Fix:** Re-run with no description for a structural crawl, then narrow once you see what flows exist.

### Crawl is blocked

> **Symptom:** Start page returns 403, 429, or auth-redirects every request.<br>
> **Cause:** Site blocks crawler-style traffic, rate-limits, or requires auth.<br>
> **Fix:** Run against a staging environment without those guards, or pre-seed credentials with `**Cookie:**` / `**Storage:**` tags in a hand-written scenario instead of crawling.

---

## `/review-scenario` can't reach the URL

### Localhost site times out

> **Symptom:** Review aborts with a connection-refused or timeout against `http://localhost:3000`.<br>
> **Cause:** The dev server is bound to `127.0.0.1` only, but the Playwright browser context resolves `localhost` differently.<br>
> **Fix:** Bind the dev server to `0.0.0.0` (most frameworks: `--host 0.0.0.0`), or change the scenario's `**URL:**` to `http://127.0.0.1:3000`.

### Auth wall blocks the review

> **Symptom:** Every test in the scenario fails because the live site redirects to a login page.<br>
> **Cause:** The flow assumes an authenticated session that the review doesn't have.<br>
> **Fix:** Add `**Cookie:**` or `**Storage:**` tags at the top of the scenario to pre-seed an auth token, or add a `**Prerequisite:**` scenario that performs the login.

---

## Scenario layout

### "I ran `/review-scenario` but it can't find my file"

> **Symptom:** `/review-scenario foo` reports that `foo` doesn't exist anywhere under `<SCENARIO_DIR>`.<br>
> **Cause:** Scenarios live under one of the three command-keyed subdirectories (`<SCENARIO_DIR>/crawl/`, `<SCENARIO_DIR>/record/`, or `<SCENARIO_DIR>/convert/`). A flat `<SCENARIO_DIR>/foo.md` won't be picked up.<br>
> **Fix:** Move the file into the appropriate folder (e.g. `mv src/test/scenarios/foo.md src/test/scenarios/record/foo.md`). Then re-run.

### Same scenario name in multiple folders

> **Symptom:** `/review-scenario checkout-flow` prompts you to disambiguate between `record/checkout-flow.md` and `convert/checkout-flow.md`.<br>
> **Cause:** Two creation commands wrote scenarios with the same kebab-case name into different folders.<br>
> **Fix:** Either pick one in the prompt, or invoke with the explicit folder form: `/review-scenario record/checkout-flow`. Renaming one of the two scenarios is also fine.

---

## `/scenario-status` reports

### "Everything is stale"

> **Symptom:** Every row in the dashboard shows ⚠ stale.<br>
> **Cause:** "Stale" means the scenario file is newer than its generated test file. Editing the scenario (or running `/review-scenario`, which rewrites it) bumps the modification time.<br>
> **Fix:** Re-run `/scenario-to-tests <name>` for each stale row. Run with no arguments to regenerate everything.

### "No crawl metadata found"

> **Symptom:** The crawl-coverage section of the dashboard is empty or shows N/A.<br>
> **Cause:** Crawl metadata is only written by `/crawl-site`. If you only used `/record-scenario` or `/doc-to-scenarios`, there is nothing to report — this is informational, not an error.<br>
> **Fix:** None needed. Run `/crawl-site` against your start URL if you want coverage data.

### Critical-path coverage shows N/A

> **Symptom:** The critical-path coverage row reports N/A.<br>
> **Cause:** No `.critical-paths.md` file exists in the project root.<br>
> **Fix:** Create `.critical-paths.md` listing the user journeys you consider critical, one per line. `/scenario-status` will pick it up on the next run.

---

## Still stuck?

If none of the above matches, gather:

1. The exact command you ran.
2. The full error output.
3. The contents of `.claude/playwright-scenarios.local.md`.
4. Your operating system and Claude Code version.

Then file an issue at [github.com/mattbobambrose/playwright-scenarios/issues](https://github.com/mattbobambrose/playwright-scenarios/issues).
