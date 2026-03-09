#!/usr/bin/env bash

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/.wsl-git-server.env}"

SERVICE_NAME="${SERVICE_NAME:-git-lan}"
SERVICE_USER="${SERVICE_USER:-git}"
SERVICE_GROUP="${SERVICE_GROUP:-$SERVICE_USER}"
SERVICE_HOME="${SERVICE_HOME:-/home/$SERVICE_USER}"
DATA_ROOT="${DATA_ROOT:-/srv/git-lan}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-127.0.0.1}"
LISTEN_PORT="${LISTEN_PORT:-2222}"
SSH_INTERNAL_PORT="${SSH_INTERNAL_PORT:-22}"
ADMIN_CLONE_HOST="${ADMIN_CLONE_HOST:-127.0.0.1}"
IMAGE_TAG="${IMAGE_TAG:-localhost/wsl-git-server:latest}"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
SERVICE_NAME='${SERVICE_NAME//\'/\'"\'"\'}'
SERVICE_USER='${SERVICE_USER//\'/\'"\'"\'}'
SERVICE_GROUP='${SERVICE_GROUP//\'/\'"\'"\'}'
SERVICE_HOME='${SERVICE_HOME//\'/\'"\'"\'}'
DATA_ROOT='${DATA_ROOT//\'/\'"\'"\'}'
LISTEN_ADDRESS='${LISTEN_ADDRESS//\'/\'"\'"\'}'
LISTEN_PORT='${LISTEN_PORT//\'/\'"\'"\'}'
SSH_INTERNAL_PORT='${SSH_INTERNAL_PORT//\'/\'"\'"\'}'
ADMIN_CLONE_HOST='${ADMIN_CLONE_HOST//\'/\'"\'"\'}'
IMAGE_TAG='${IMAGE_TAG//\'/\'"\'"\'}'
EOF
}

require_cmd() {
    local cmd="$1"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$cmd" >&2
        exit 1
    fi
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        printf 'This script must be run as root or via sudo.\n' >&2
        exit 1
    fi
}

is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

service_uid() {
    id -u "$SERVICE_USER"
}

service_quadlet_dir() {
    printf '%s/.config/containers/systemd\n' "$SERVICE_HOME"
}

service_systemd_dir() {
    printf '%s/.config/systemd/user\n' "$SERVICE_HOME"
}

runtime_service_name() {
    printf '%s\n' "$SERVICE_NAME"
}

legacy_proxy_service_name() {
    printf '%s-proxy\n' "$SERVICE_NAME"
}

ssh_service_name() {
    printf '%s-ssh\n' "$SERVICE_NAME"
}

run_as_service_user() {
    local uid

    uid="$(service_uid)"
    sudo -u "$SERVICE_USER" env \
        HOME="$SERVICE_HOME" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
    bash -lc 'cd "$HOME" && exec "$@"' bash "$@"
}

have_noninteractive_sudo() {
    sudo -n true >/dev/null 2>&1
}

run_sudo_noninteractive() {
    if ! have_noninteractive_sudo; then
        printf 'sudo access is required for this operation. Re-run from a shell with an active sudo session.\n' >&2
        return 1
    fi

    sudo -n "$@"
}

run_user_systemctl() {
    run_sudo_noninteractive systemctl --machine="${SERVICE_USER}@" --user "$@"
}

ensure_subid_range() {
    local file="$1"
    local name="$2"
    local count="$3"
    local start

    if grep -qE "^${name}:" "$file" 2>/dev/null; then
        return
    fi

    start="$({ awk -F: 'BEGIN { max = 100000 } NF >= 3 { end = $2 + $3; if (end > max) max = end } END { print max }' "$file" 2>/dev/null || printf '100000\n'; } | tail -n 1)"
    printf '%s:%s:%s\n' "$name" "$start" "$count" >> "$file"
}

render_template() {
    local template_path="$1"
    local output_path="$2"

    sed \
        -e "s|__SERVICE_NAME__|$SERVICE_NAME|g" \
        -e "s|__IMAGE_TAG__|$IMAGE_TAG|g" \
        -e "s|__DATA_ROOT__|$DATA_ROOT|g" \
        -e "s|__LISTEN_ADDRESS__|$LISTEN_ADDRESS|g" \
        -e "s|__LISTEN_PORT__|$LISTEN_PORT|g" \
        -e "s|__SSH_INTERNAL_PORT__|$SSH_INTERNAL_PORT|g" \
        "$template_path" > "$output_path"
}