#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config

require_cmd podman
require_cmd sudo
require_cmd systemctl
require_cmd loginctl

if ! is_wsl; then
    printf 'This setup is intended for WSL.\n' >&2
    exit 1
fi

if [[ "$(podman info --format '{{.Host.CgroupsVersion}}')" != "v2" ]]; then
    printf 'Podman must be using cgroup v2.\n' >&2
    exit 1
fi

printf 'Prerequisites look broadly usable.\n'
printf 'WSL distro: %s\n' "${WSL_DISTRO_NAME:-unknown}"
printf 'Podman version: %s\n' "$(podman --version)"
printf 'cgroups: %s\n' "$(podman info --format '{{.Host.CgroupsVersion}}')"
printf 'systemd state: %s\n' "$(systemctl is-system-running 2>/dev/null || true)"
printf 'Configured listen address: %s\n' "$LISTEN_ADDRESS"
printf 'Configured listen port: %s\n' "$LISTEN_PORT"

if ! grep -q '^default_hierarchy=unified' /proc/cmdline 2>/dev/null; then
    :
fi

printf '\nManual checks still worth making:\n'
printf -- '- Confirm WSL systemd support is enabled.\n'
printf -- '- Prefer mirrored networking if this should be directly reachable from the LAN.\n'
printf -- '- Make sure the chosen listen address matches the reachable LAN-facing address.\n'