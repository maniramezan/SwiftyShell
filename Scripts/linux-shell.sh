#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec "${script_dir}/docker-linux-swift.sh" /bin/bash "$@"
