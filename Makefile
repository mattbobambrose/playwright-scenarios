VERSION=$(shell grep '^version =' build.gradle.kts | head -1 | sed 's/.*"\(.*\)"/\1/' | sed 's/-SNAPSHOT//')

default: versioncheck

clean:
	./gradlew clean

build: clean
	./gradlew build

tests:
	./gradlew --rerun-tasks check

versioncheck:
	./gradlew dependencyUpdates

docker-local: build
	docker buildx build --platform linux/amd64,linux/arm64 -t mattbobambrose/eocare-pipeline .

docker-push: build
	docker buildx build --platform linux/amd64,linux/arm64 -t mattbobambrose/eocare-pipeline --push .

deploy: docker-push
	bash secrets/deploy-app.sh
	say "Deployed to Digital Ocean"

depends:
	./gradlew dependencies

run:
	./gradlew run

kdocs:
	./gradlew dokkaGeneratePublicationHtml

clean-docs:
	rm -rf website/website-validation/site
	rm -rf website/website-validation/.cache

site: clean-docs
	cd website/website-validation && uv run zensical serve

publish-local:
	./gradlew publishToMavenLocal

publish-local-snapshot:
	./gradlew -PoverrideVersion=$(VERSION)-SNAPSHOT publishToMavenLocal

GPG_ENV = \
	ORG_GRADLE_PROJECT_signingInMemoryKey="$$(gpg --armor --export-secret-keys $$GPG_SIGNING_KEY_ID)" \
	ORG_GRADLE_PROJECT_signingInMemoryKeyPassword=$$(security find-generic-password -a "gpg-signing" -s "gradle-signing-password" -w)

publish-snapshot:
	$(GPG_ENV) ./gradlew -PoverrideVersion=$(VERSION)-SNAPSHOT publishToMavenCentral

publish-maven-central:
	$(GPG_ENV) ./gradlew publishAndReleaseToMavenCentral

upgrade-wrapper:
	./gradlew wrapper --gradle-version=9.4.1 --distribution-type=bin
