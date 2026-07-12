.PHONY: help build test lint validate-traits validate-docc docc coverage check linux-shell linux-build linux-test linux-ci linux-ci-amd64

MINIMUM_LINE_COVERAGE ?= 84

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make build            Run the local release build with warnings as errors' \
	  '  make test             Run the local test suite with warnings as errors' \
	  '  make lint             Run swift-format lint --strict' \
	  '  make validate-traits  Run the package trait validator with warnings as errors' \
	  '  make validate-docc    Run the DocC coverage validator with warnings as errors' \
	  '  make docc             Build the DocC site with warnings as errors' \
	  '  make coverage         Enforce the package coverage threshold locally' \
	  '  make check            Run the local gates that mirror CI' \
	  '  make linux-shell      Open the pinned Swift Linux Docker shell' \
	  '  make linux-build      Run the Linux Docker release build with warnings as errors' \
	  '  make linux-test       Run the Linux Docker test command with warnings as errors' \
	  '  make linux-ci         Run the Linux Docker build + test flow' \
	  '  make linux-ci-amd64   Run Linux CI flow under linux/amd64'

build:
	swift build -c release -Xswiftc -warnings-as-errors

test:
	swift test -Xswiftc -warnings-as-errors

lint:
	swift-format lint --strict --recursive Sources Tests Scripts

validate-traits:
	swift -warnings-as-errors Scripts/validate-traits.swift

validate-docc:
	swift -warnings-as-errors Scripts/validate-docc-coverage.swift

docc:
	swift package -Xswiftc -warnings-as-errors --allow-writing-to-directory docs generate-documentation --target SwiftyShell --output-path docs --transform-for-static-hosting --hosting-base-path SwiftyShell

coverage:
	path="$$(swift test --enable-all-traits --enable-code-coverage -Xswiftc -warnings-as-errors --show-codecov-path)"; \
	swift test --enable-all-traits --enable-code-coverage -Xswiftc -warnings-as-errors; \
	swift -warnings-as-errors Scripts/validate-code-coverage.swift --input "$$path" --minimum-line-coverage "$(MINIMUM_LINE_COVERAGE)" --all-traits

check: lint test validate-traits validate-docc docc coverage linux-ci

linux-shell:
	Scripts/linux-shell.sh

linux-build:
	Scripts/linux-build.sh

linux-test:
	Scripts/linux-test.sh

linux-ci:
	Scripts/linux-ci.sh

linux-ci-amd64:
	SWIFTYSHELL_LINUX_PLATFORM=linux/amd64 Scripts/linux-ci.sh
