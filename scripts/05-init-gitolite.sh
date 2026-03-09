#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_KEY_PATH="${ADMIN_KEY_PATH:-}"

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config

if [[ $# -gt 0 ]]; then
    ADMIN_KEY_PATH="$1"
fi

if [[ -z "$ADMIN_KEY_PATH" ]]; then
    printf 'Usage: %s /path/to/admin.pub\n' "$0" >&2
    exit 1
fi

if [[ ! -f "$ADMIN_KEY_PATH" ]]; then
    printf 'Admin public key not found: %s\n' "$ADMIN_KEY_PATH" >&2
    exit 1
fi

sudo install -D -m 0600 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$ADMIN_KEY_PATH" "$DATA_ROOT/state/admin.pub"
run_user_systemctl restart "$(ssh_service_name).service"

for _ in $(seq 1 30); do
    if sudo test -f "$DATA_ROOT/gitolite-admin/conf/gitolite.conf"; then
        printf 'gitolite initialized.\n'
        exit 0
    fi
    sleep 1
done

printf 'gitolite did not finish initializing in time.\n' >&2
printf 'Check logs with: sudo systemctl --machine=%s@ --user status %s.service\n' "$SERVICE_USER" "$(ssh_service_name)" >&2
exit 1