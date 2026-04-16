---
name: record-scenario
description: Record a new website validation scenario by driving a real browser. Launches Playwright codegen, captures clicks/typing/assertions, then writes a draft scenario markdown file to the project's configured scenario directory.
arguments:
  - name: name
    description: Optional kebab-case scenario name, optionally followed by flags. If the name is omitted, it is inferred from the recorded actions. Supported flag - --no-review (skip the auto-chain into /review-scenario at the end).
    required: false
---

# Record Scenario

Create a new scenario by *demonstrating* it in a browser instead of writing markdown from scratch. This command launches Playwright codegen, lets the user drive a real browser, captures their actions and marked assertions, and produces a draft `<SCENARIO_DIR>/<name>.md` file that feeds into the existing `/review-scenario` → `/scenario-to-tests` pipeline.

## Argument parsing

Split the argument string into **flags** (tokens starting with `--`) and a **name** (the first non-flag token, if any):

- `--no-review` — skip the auto-chain into `/review-scenario` at step 10. Off by default (review runs automatically).

Any unknown `--`-prefixed token should be reported as an error before doing any work.

## Prerequisites

- The Gradle task `recordScenario` must exist in `build.gradle.kts` (it should — if not, stop and tell the user).
- This is a destructive UI operation: a real browser window will open. Do not run it inside a subagent or background task.

## Steps

### 0. Load project config

Invoke the `loading-config` skill to resolve `<SCENARIO_DIR>`, `<TEST_DIR>`, `<TEST_LANGUAGE>`, and `<TEST_FRAMEWORK>`. If `.claude/playwright-scenarios.local.md` is missing, the skill prompts the user and creates it before returning. Only `<SCENARIO_DIR>` is needed for this command, but the bootstrap happens here rather than later so the user sees the prompts before the browser window opens.

### 1. Determine scenario name

- **If the user invoked the command with an argument**, treat it as the scenario name. Validate it is kebab-case (no spaces, uppercase, or extensions); reject and ask for a clean name if not.
- **If no argument was provided**, defer naming. Do not ask the user for a name up front — you will infer it from the recorded actions in step 6. Use a temporary recording filename (e.g. `build/recordings/untitled-<timestamp>.java`) for step 4.

Always prompt for the **Start URL**. Do not supply a default — require the user to enter one.

### 2. Check for collisions (only if name is known)

If the name was supplied as an argument, check whether `<SCENARIO_DIR>/<name>.md` already exists. If it does, ask whether to overwrite, pick a new name, or cancel. Do not silently overwrite.

If the name will be inferred, skip this step — collision handling happens in step 6.

### 3. Brief the user on recording controls

Tell the user, verbatim-ish:

> A Chromium window and a **Playwright Inspector** panel will open. Drive the browser through the flow you want to test.
>
> To mark an **expected outcome** (what a test should assert), use the Inspector toolbar:
> - **Assert visibility** — click, then click an element that should be visible.
> - **Assert text** — click, then click an element whose text should match.
> - **Assert value** — click, then click a form field whose value should match.
>
> When you're done, close the browser window. I'll take it from there.

### 4. Run the recorder

Run:

```
./gradlew recordScenario -Purl=<start-url> -Pout=build/recordings/<recording-filename>.java
```

Where `<recording-filename>` is the supplied scenario name (if given) or the temporary `untitled-<timestamp>` filename from step 1.

This blocks until the user closes the browser. Do not set a short timeout — the user may record for several minutes. Use a long Bash timeout (e.g. 600000 ms).

**If the task fails with `Executable doesn't exist at .../ms-playwright/...`**, Playwright's browser binaries are not yet downloaded. Run the one-time install task and then retry:

```
./gradlew installPlaywrightBrowsers
```

If that task also doesn't exist in the project, point the user at the README's "Host Project Setup" section — both tasks need to be added to their `build.gradle.kts`.

### 5. Read the recording

Read the recording file written in step 4. It will contain Playwright Java API calls like:

```java
page.navigate("https://example.com/home");
page.getByRole(AriaRole.LINK, new Page.GetByRoleOptions().setName("Log In")).click();
page.getByLabel("Email").fill("test@example.com");
assertThat(page.getByText("Thank you!")).isVisible();
```

If the file is empty or contains no `page.` calls, something went wrong — tell the user and stop.

### 6. Infer the scenario name (only if not supplied)

If no name was supplied as an argument, infer a kebab-case name from the recorded actions. Use these signals, in order:

1. The primary user intent (e.g. a form submission, a login attempt, navigation to a specific page).
2. The most distinctive action sequence (e.g. clicking "Log In" and filling credentials → `login-…`).
3. The terminal URL or page section if the flow ends somewhere meaningful.

Produce a short name (2–4 kebab-case words) that would make sense as a test filename. Examples: `login-invalid-credentials`, `email-signup-form`, `care-plan-intake-basics`.

Then check for collisions: if `<SCENARIO_DIR>/<inferred-name>.md` already exists, try `-v2`, `-v3`, etc. until a free name is found, or ask the user to pick a new name. Do not silently overwrite.

Briefly tell the user the inferred name and give them a chance to override it before writing.

### 7. Convert to scenario markdown

The `authoring-scenarios` skill is the authoritative reference for the flat-markdown format, voice, selector rules, test grouping, and known gotchas (HTML5 validation tooltips, cross-origin links). Follow it. If one or more `.md` files already exist directly under `<SCENARIO_DIR>` (excluding `SCENARIOS.md` and subdirectories), glance at one to match the host project's house style.

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

### 8. Write the scenario

Write the converted markdown to `<SCENARIO_DIR>/<name>.md` using the Write tool, creating `<SCENARIO_DIR>` if it doesn't yet exist. If the recording was saved under a temporary `untitled-<timestamp>.java` filename, leave it as-is in `build/recordings/` — do not rename it. The scenario markdown is the authoritative artifact.

### 9. Report to the user

Tell the user:
- The path of the draft file.
- A one-line summary of what was recorded (e.g. "3 actions, 2 assertions across 1 test").
- If `--no-review` was **not** passed: that you are about to chain into `/review-scenario <name>` automatically (next step).
- If `--no-review` **was** passed: that review is skipped; they can run `/review-scenario <name>` manually when ready.
- That `/scenario-to-tests <name>` is always a manual follow-up.

### 10. Auto-chain into `/review-scenario`

**If `--no-review` was passed**, skip this step entirely.

Otherwise, immediately execute the `/review-scenario <name>` command inline — run its procedure (audit the just-written scenario against the live site and apply improvements) as a continuation of this turn. Do not wait for user confirmation. The newly written scenario almost always benefits from a live-site audit before tests are generated.

Do **not** auto-run `/scenario-to-tests` — test generation is a heavier step that the user should opt into explicitly.
