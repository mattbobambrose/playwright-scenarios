---
name: record-scenario
description: Record a new website validation scenario by driving a real browser. Launches Playwright codegen, captures clicks/typing/assertions, then writes a scenario markdown file to <SCENARIO_DIR>/record/. Accepts an optional Start URL so the codegen browser opens directly there instead of prompting.
summary: Launch Playwright codegen, capture a real user flow, and write a scenario to `<scenario_dir>/record/<name>.md`. Optionally accepts a Start URL so the browser opens straight to it.
signature: /record-scenario [url] [name]
arguments:
  - name: url
    description: Optional Start URL (`http://...` or `https://...`). If supplied, the codegen browser opens there directly. If omitted, you'll be prompted for one.
    required: false
  - name: name
    description: Optional kebab-case scenario name. If omitted, it is inferred from the recorded actions.
    required: false
---

# Record Scenario

Create a new scenario by *demonstrating* it in a browser instead of writing markdown from scratch. This command launches Playwright codegen, lets the user drive a real browser, captures their actions and marked assertions, and writes the result to `<SCENARIO_DIR>/record/<name>.md`.

The scenario is the canonical artifact. If the user wants to eyeball or hand-edit it before running `/review-scenario`, they do so in place.

## Argument parsing

Tokens are content-detected; order does not matter:

- A token that starts with `http://` or `https://` is the **Start URL**.
- A non-URL, non-flag token is the **name** (must be kebab-case — no spaces, uppercase, or extensions).

All flag-prefixed tokens (`--*`) are unknown — report as an error before doing any work.

**Examples:**

```
/record-scenario
/record-scenario checkout-flow
/record-scenario https://mysite.com
/record-scenario https://mysite.com checkout-flow
/record-scenario checkout-flow https://mysite.com
```

## Prerequisites

- The Gradle task `recordScenario` must exist in `build.gradle.kts` (it should — if not, stop and tell the user).
- This is a destructive UI operation: a real browser window will open. Do not run it inside a subagent or background task.

## Phases

### Phase 0: Load project config

Invoke the `loading-config` skill to resolve `<SCENARIO_DIR>`, `<TEST_DIR>`, `<TEST_LANGUAGE>`, and `<TEST_FRAMEWORK>`. If `.claude/playwright-scenarios.local.md` is missing, the skill prompts the user and creates it before returning. If `loading-config` returns `MALFORMED_CONFIG`, abort and tell the user to run `/playwright-scenarios-config` to repair. Only `<SCENARIO_DIR>` is needed for this command, but the bootstrap happens here rather than later so the user sees the prompts before the browser window opens.

### Phase 1: Determine scenario name and Start URL

**Scenario name:**

- **If the parsed argument string included a name token**, treat it as the scenario name. Validate it is kebab-case (no spaces, uppercase, or extensions); reject and ask for a clean name if not.
- **If no name was provided**, defer naming. Do not ask the user for a name up front — you will infer it from the recorded actions in Phase 6. Use a temporary recording filename (e.g. `build/recordings/untitled-<timestamp>.java`) for Phase 4.

**Start URL:**

- **If the parsed argument string included a URL token**, use it as the Start URL.
- **Otherwise**, prompt the user to enter one. Do not supply a default.

### Phase 2: Check for collisions (only if name is known)

The output directory is `<SCENARIO_DIR>/record/`. Ensure it exists; create it if not.

If the name was supplied as an argument, check whether `<SCENARIO_DIR>/record/<name>.md` already exists. If it does, ask whether to overwrite, pick a new name, or cancel. Do not silently overwrite.

If the name will be inferred, skip this phase — collision handling happens in Phase 6.

### Phase 3: Brief the user on recording controls

Tell the user, verbatim-ish:

> A Chromium window and a **Playwright Inspector** panel will open. Drive the browser through the flow you want to test.
>
> To mark an **expected outcome** (what a test should assert), use the Inspector toolbar:
> - **Assert visibility** — click, then click an element that should be visible.
> - **Assert text** — click, then click an element whose text should match.
> - **Assert value** — click, then click a form field whose value should match.
>
> When you're done, close the browser window. I'll take it from there.

### Phase 4: Run the recorder

Run:

```
./gradlew recordScenario -Purl=<start-url> -Pout=build/recordings/<recording-filename>.java
```

Where `<recording-filename>` is the supplied scenario name (if given) or the temporary `untitled-<timestamp>` filename from Phase 1.

This blocks until the user closes the browser. Do not set a short timeout — the user may record for several minutes. Use a long Bash timeout (e.g. 600000 ms).

**If the task fails with `Executable doesn't exist at .../ms-playwright/...`**, Playwright's browser binaries are not yet downloaded. Run the one-time install task and then retry:

```
./gradlew installPlaywrightBrowsers
```

If that task also doesn't exist in the project, point the user at the README's "Host Project Setup" section — both tasks need to be added to their `build.gradle.kts`.

### Phase 5: Read the recording

Read the recording file written in Phase 4. It will contain Playwright Java API calls like:

```java
page.navigate("https://mysite.com/home");
page.getByRole(AriaRole.LINK, new Page.GetByRoleOptions().setName("Log In")).click();
page.getByLabel("Email").fill("test@example.com");
assertThat(page.getByText("Thank you!")).isVisible();
```

If the file is empty or contains no `page.` calls, something went wrong — tell the user and stop.

### Phase 6: Infer the scenario name (only if not supplied)

If no name was supplied as an argument, infer a kebab-case name from the recorded actions. Use these signals, in order:

1. The primary user intent (e.g. a form submission, a login attempt, navigation to a specific page).
2. The most distinctive action sequence (e.g. clicking "Log In" and filling credentials → `login-…`).
3. The terminal URL or page section if the flow ends somewhere meaningful.

Produce a short name (2–4 kebab-case words) that would make sense as a test filename. Examples: `login-invalid-credentials`, `email-signup-form`, `checkout-happy-path`.

Then check for collisions: if `<SCENARIO_DIR>/record/<inferred-name>.md` already exists, increment the numeric suffix (`-v2`, `-v3`, ...) until a free name is found. Do not silently overwrite.

Briefly tell the user the inferred name and give them a chance to override it before writing.

### Phase 7: Convert to scenario markdown

The `authoring-scenarios` skill is the authoritative reference for the flat-markdown format, voice, selector rules, test grouping, and known gotchas (HTML5 validation tooltips, cross-origin links). Follow it. If one or more `.md` files already exist directly under `<SCENARIO_DIR>/record/`, glance at one to match the host project's house style.

**Playwright Java API → scenario markdown conversion:**

- `page.navigate(url)` → first bullet of a test: `- **Action:** Navigate to <url>` (or fold into the header `**URL:**` if it matches the start URL).
- `page.getByRole(..., setName("X")).click()` → `- **Action:** Click "X"`.
- `page.getByLabel("Email").fill("foo@bar")` → two bullets:
  - `- **Email:** foo@bar`
  - `- **Action:** Enter email ...`
- `page.selectOption(...)` → `- **Action:** Select "<value>" from the <label> dropdown`.
- `page.setViewportSize(w, h)` → `- **Viewport:** <w>x<h>`.
- `assertThat(locator).isVisible()` → `- **Expected:** The <element description> is visible`.
- `assertThat(locator).hasText("X")` → `- **Expected:** The <element description> shows "X"`.
- `assertThat(locator).hasValue("X")` → `- **Expected:** The <field description> contains "X"`.

**Test grouping:** one continuous flow → one `## Test 1:` section; distinct sub-flows (same form with different inputs, or a sequence separated by re-navigation) → `## Test 1:`, `## Test 2:`, etc. Derive each Test title from the primary action in that group.

### Phase 8: Write the scenario file

Write the converted markdown to `<SCENARIO_DIR>/record/<name>.md` using the Write tool. Include a provenance blockquote after the description line:

> Recorded by `/record-scenario` from `<start-url>`. Review before feeding into `/scenario-to-tests`.

If the recording was saved under a temporary `untitled-<timestamp>.java` filename, leave it as-is in `build/recordings/` — do not rename it. The scenario markdown is the authoritative artifact.

### Phase 9: Report to the user

Tell the user:
- The path of the written file.
- A one-line summary of what was recorded (e.g. "3 actions, 2 assertions across 1 test").
- Next step: review the scenario in place if you want to hand-edit, then run `/review-scenario <name>` to audit it against the live site.

Do **not** auto-chain into `/review-scenario`. The user decides when to run it.
