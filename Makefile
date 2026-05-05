.PHONY: help test build linux-shell linux-build linux-test linux-ci linux-ci-amd64

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make build            Run swift build locally on macOS/Linux' \
	  '  make test             Run swift test locally on macOS/Linux' \
	  '  make validate-traits  Run the package trait validator' \
	  '  make validate-docc    Run the DocC coverage validator' \
	  '  make check            Run local host + Linux validation' \
	  '  make linux-shell      Open the pinned Swift Linux Docker shell' \
	  '  make linux-build      Run the Linux Docker release build' \
	  '  make linux-test       Run the Linux Docker test command' \
	  '  make linux-ci         Run the Linux Docker build + test flow' \
	  '  make linux-ci-amd64   Run Linux CI flow under linux/amd64'

build:
	swift build

test:
	swift test

validate-traits:
	swift Scripts/validate-traits.swift

validate-docc:
	swift Scripts/validate-docc-coverage.swift

check: test validate-traits validate-docc linux-ci

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
