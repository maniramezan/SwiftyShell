#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
scratch_path="${SWIFTYSHELL_LINUX_SCRATCH_PATH:-.build/linux-docker}"

exec "${script_dir}/docker-linux-swift.sh" swift build --scratch-path "${scratch_path}" -c release -Xswiftc -warnings-as-errors "$@"
