#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

image="${SWIFTYSHELL_LINUX_IMAGE:-swift:6.1.3-noble}"
platform="${SWIFTYSHELL_LINUX_PLATFORM:-}"
workspace="/workspace"
container_home="/swift-home"
docker_home="${repo_root}/.build/docker-home"
docker_tmp="${repo_root}/.build/docker-tmp"

if ! command -v docker >/dev/null 2>&1; then
    printf 'docker is required for Linux validation helpers.\n' >&2
    exit 1
fi

mkdir -p "${docker_home}/.swiftpm/cache" "${docker_tmp}"

docker_args=(run --rm --init -w "${workspace}")

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
elif [[ -t 0 || -t 1 ]]; then
    docker_args+=(-i)
fi

if command -v id >/dev/null 2>&1; then
    docker_args+=(--user "$(id -u):$(id -g)")
fi

if [[ -n "${platform}" ]]; then
    docker_args+=(--platform "${platform}")
fi

docker_args+=(
    -v "${repo_root}:${workspace}"
    -v "${docker_home}:${container_home}"
    -v "${docker_tmp}:/tmp"
    -e "HOME=${container_home}"
    "${image}"
    "$@"
)

exec docker "${docker_args[@]}"
