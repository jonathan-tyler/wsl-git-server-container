#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

load_config
require_root

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    printf 'Service user %s does not exist yet. Run 02-create-service-user.sh first.\n' "$SERVICE_USER" >&2
    exit 1
fi

render_template "$ROOT_DIR/quadlet/git-lan.network" "$TMP_DIR/${SERVICE_NAME}.network"
render_template "$ROOT_DIR/quadlet/git-lan.container" "$TMP_DIR/${SERVICE_NAME}.container"
render_template "$ROOT_DIR/quadlet/git-lan-ssh.container" "$TMP_DIR/$(ssh_service_name).container"
render_template "$ROOT_DIR/systemd/git-lan.socket" "$TMP_DIR/${SERVICE_NAME}.socket"

install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$(service_quadlet_dir)"
install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$(service_systemd_dir)"

run_user_systemctl stop "$(runtime_service_name).service" >/dev/null 2>&1 || true
run_user_systemctl stop "$(legacy_proxy_service_name).service" >/dev/null 2>&1 || true
run_user_systemctl stop "$(ssh_service_name).service" >/dev/null 2>&1 || true
rm -f "$(service_systemd_dir)/$(legacy_proxy_service_name).service"

install -m 0644 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$TMP_DIR/${SERVICE_NAME}.network" "$(service_quadlet_dir)/${SERVICE_NAME}.network"
install -m 0644 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$TMP_DIR/${SERVICE_NAME}.container" "$(service_quadlet_dir)/${SERVICE_NAME}.container"
install -m 0644 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$TMP_DIR/$(ssh_service_name).container" "$(service_quadlet_dir)/$(ssh_service_name).container"
install -m 0644 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$TMP_DIR/${SERVICE_NAME}.socket" "$(service_systemd_dir)/${SERVICE_NAME}.socket"

run_user_systemctl daemon-reload
run_user_systemctl enable "${SERVICE_NAME}.socket"
run_user_systemctl start "$(ssh_service_name).service"
run_user_systemctl start "${SERVICE_NAME}.socket"

printf 'Installed units for %s\n' "$SERVICE_NAME"