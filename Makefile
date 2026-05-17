.PHONY: default help clean-docs site

default: help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

clean-docs: ## Remove generated docs site and cache
	rm -rf website/playwright-scenarios/site
	rm -rf website/playwright-scenarios/.cache

site: clean-docs ## Build and serve the docs site
	cd website/playwright-scenarios && uv run zensical serve
