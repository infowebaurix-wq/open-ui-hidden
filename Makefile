SHELL := /usr/bin/env bash

.PHONY: test test-static test-docker-smoke update-digests check-digests

test: test-static

test-static:
	./tests/test_static.sh

test-docker-smoke:
	./tests/test_compose_smoke.sh

update-digests:
	./scripts/update-image-digests.sh

check-digests:
	./scripts/update-image-digests.sh --check
