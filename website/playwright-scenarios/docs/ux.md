# Tutorial
## Setup:
1. Install Git, Docker, and Claude
2. Clone template repo in language of choice:
- kotlin template link
- python template link
- typeScript template link
3. Start docker image
- Docker run imageName
4. Start Claude Code window with claude
5. Install plugin
- /plugin marketplace add mattbobambrose/playwright-scenarios
- /plugin install playwright-scenarios@playwright-scenarios

## Scenario generation commands

### /crawl-site http://localhost:8080
#### Once satisfied with drafts, move them into the main scenarios directory so that
/review-scenario can find them and generate tests. (Make promoting from drafts easier)
#### /review-scenario (Give option for one scenario at a time or all at once)
#### /scenario-to-tests
#### /scenario-status

### /record-scenario
#### /review-scenario
#### /scenario-to-tests
#### /scenario-status

### /doc-to-scenario docFileName
#### /review-scenario
#### /scenario-to-tests
#### /scenario-status

## Options for how to generate scenarios

/crawl-site: Automated scenario generation, claude comes up with test scenarios and runs them with
minimal user input
1. /crawl-site dockerImageUrl
- Triggers loading config skill where user answers setup questions

/record-scenario: User knows the user experience they want to test and drives the browser to
demonstrate it, with playwright marking each action. Claude then translates the recording into
a scenario markdown file.

/doc-to-scenario: User has pre-existing idea for what they want to test and uses plugin to convert doc
into optimized format
