#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config
require_root
require_cmd loginctl

SERVICE_CONFIG_ROOT="$SERVICE_HOME/.config"
SERVICE_CONTAINERS_ROOT="$SERVICE_CONFIG_ROOT/containers"
SERVICE_SYSTEMD_ROOT="$SERVICE_CONFIG_ROOT/systemd"

if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    groupadd --system "$SERVICE_GROUP"
fi

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd \
        --system \
        --gid "$SERVICE_GROUP" \
        --home-dir "$SERVICE_HOME" \
        --create-home \
        --shell /usr/sbin/nologin \
        "$SERVICE_USER"
fi

ensure_subid_range /etc/subuid "$SERVICE_USER" 65536
ensure_subid_range /etc/subgid "$SERVICE_USER" 65536

install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT/repos"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT/gitolite-admin"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT/state"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT/state/git-ssh"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$DATA_ROOT/state/ssh"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$SERVICE_CONFIG_ROOT"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$SERVICE_CONTAINERS_ROOT"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$SERVICE_SYSTEMD_ROOT"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$(service_quadlet_dir)"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$(service_systemd_dir)"

loginctl enable-linger "$SERVICE_USER"
save_config

printf 'Service user ready: %s\n' "$SERVICE_USER"
printf 'Service home: %s\n' "$SERVICE_HOME"
printf 'Data root: %s\n' "$DATA_ROOT"