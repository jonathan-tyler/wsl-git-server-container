#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config
require_cmd podman
require_cmd mktemp

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    printf 'Service user %s does not exist yet. Run 02-create-service-user.sh first.\n' "$SERVICE_USER" >&2
    exit 1
fi

BUILD_CONTEXT_DIR="$(mktemp -d /tmp/wsl-git-server-build.XXXXXX)"
trap 'rm -rf "$BUILD_CONTEXT_DIR"' EXIT

cp "$ROOT_DIR/Containerfile" "$BUILD_CONTEXT_DIR/Containerfile"
cp -R "$ROOT_DIR/container" "$BUILD_CONTEXT_DIR/container"
chmod -R a+rX "$BUILD_CONTEXT_DIR"

run_as_service_user bash -lc "cd '$BUILD_CONTEXT_DIR' && podman build --pull=newer -t '$IMAGE_TAG' -f '$BUILD_CONTEXT_DIR/Containerfile' '$BUILD_CONTEXT_DIR'"

printf 'Built image: %s\n' "$IMAGE_TAG"