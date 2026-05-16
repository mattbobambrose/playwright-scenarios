default: site

clean-docs:
	rm -rf website/playwright-scenarios/site
	rm -rf website/playwright-scenarios/.cache

site: clean-docs
	cd website/playwright-scenarios && uv run zensical serve
