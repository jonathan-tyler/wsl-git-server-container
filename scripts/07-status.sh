#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config

printf 'Service name: %s\n' "$SERVICE_NAME"
printf 'Service user: %s\n' "$SERVICE_USER"
printf 'Data root: %s\n' "$DATA_ROOT"
printf 'Listen: %s:%s\n' "$LISTEN_ADDRESS" "$LISTEN_PORT"
printf '\n'

if id "$SERVICE_USER" >/dev/null 2>&1; then
    printf 'Service user exists with uid %s\n' "$(service_uid)"
else
    printf 'Service user does not exist yet.\n'
    exit 0
fi

if ! have_noninteractive_sudo; then
    printf '\nSudo is required to inspect the %s user systemd instance.\n' "$SERVICE_USER"
    printf 'Open a root shell or refresh sudo, then re-run this script.\n'
    exit 0
fi

printf '\nSystemd socket status:\n'
run_sudo_noninteractive systemctl --machine="${SERVICE_USER}@" --user --no-pager --full status "${SERVICE_NAME}.socket" || true

printf '\nProxy service status:\n'
run_sudo_noninteractive systemctl --machine="${SERVICE_USER}@" --user --no-pager --full status "$(runtime_service_name).service" || true

printf '\nSSH service status:\n'
run_sudo_noninteractive systemctl --machine="${SERVICE_USER}@" --user --no-pager --full status "$(ssh_service_name).service" || true

printf '\nRootless Podman network:\n'
run_as_service_user podman network inspect "$SERVICE_NAME" || true

printf '\nRootless Podman containers:\n'
run_as_service_user podman ps -a || true