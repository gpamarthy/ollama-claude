.PHONY: help ci nightly lint test unit contract integration simulation chaos property clean

SHELL := /bin/bash

SH_FILES := $(shell git ls-files '*.sh' 2>/dev/null || find . -name '*.sh' -not -path './tests/.bats-tmp/*')
PS1_FILES := $(shell git ls-files '*.ps1' 2>/dev/null || find . -name '*.ps1')

help:
	@echo "make ci         - static + unit + contract + integration (PR gate)"
	@echo "make nightly    - + simulation + chaos + property"
	@echo "make lint       - shellcheck + shfmt"
	@echo "make test       - alias for: unit + contract"
	@echo "make unit       - bats tests/unit"
	@echo "make integration - tests/integration/smoke.sh"
	@echo "make clean      - remove test scratch"

ci: lint unit contract integration

nightly: ci simulation chaos property

lint:
	@which shellcheck >/dev/null 2>&1 || { echo "shellcheck not found"; exit 1; }
	@which shfmt >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@if [ -n "$(SH_FILES)" ]; then \
		echo "shellcheck $(words $(SH_FILES)) files"; \
		shellcheck $(SH_FILES); \
		echo "shfmt -d $(words $(SH_FILES)) files"; \
		shfmt -i 2 -ci -sr -d $(SH_FILES); \
	fi

test: unit contract

unit:
	@which bats >/dev/null 2>&1 || { echo "bats not found; install bats-core"; exit 1; }
	bats tests/unit

contract:
	@if [ -d tests/contract ] && ls tests/contract/*.sh >/dev/null 2>&1; then \
		bats tests/contract; \
	else \
		echo "no contract tests yet"; \
	fi

integration:
	@if [ -f tests/integration/smoke.sh ]; then \
		bash tests/integration/smoke.sh; \
	else \
		echo "no integration tests yet"; \
	fi

simulation:
	@if [ -f tests/simulation/run-matrix.sh ]; then \
		bash tests/simulation/run-matrix.sh; \
	else \
		echo "no simulation tests yet"; \
	fi

chaos:
	@if [ -d tests/chaos ]; then \
		for t in tests/chaos/*.sh; do \
			[ -f "$$t" ] && echo "=== $$t ===" && bash "$$t"; \
		done; \
	fi

property:
	@if [ -f tests/property/render_invariants.sh ]; then \
		bash tests/property/render_invariants.sh; \
	fi

clean:
	rm -rf tests/.bats-tmp tests/integration/.cache .test-state
