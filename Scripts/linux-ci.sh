#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/linux-build.sh" "$@"
"${script_dir}/linux-test.sh" "$@"
