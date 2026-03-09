#!/usr/bin/env bash

set -euo pipefail

GIT_HOME="${GIT_HOME:-/var/lib/gitolite}"
STATE_DIR="${STATE_DIR:-/var/lib/git-server}"
ADMIN_KEY_PATH="${ADMIN_KEY_PATH:-$STATE_DIR/admin.pub}"
HOST_KEY_DIR="$STATE_DIR/ssh"

generate_host_key() {
    local key_type="$1"
    local key_path="$2"

    if [[ -f "$key_path" ]]; then
        return
    fi

    ssh-keygen -q -t "$key_type" -N '' -f "$key_path"
}

ensure_layout() {
    mkdir -p \
        "$GIT_HOME/.ssh" \
        "$GIT_HOME/.gitolite/logs" \
        "$GIT_HOME/repositories" \
        "$STATE_DIR" \
        "$HOST_KEY_DIR" \
        /run/sshd

    chown -R git:git "$GIT_HOME" "$STATE_DIR"
    chmod 0700 "$GIT_HOME/.ssh"
}

ensure_host_keys() {
    generate_host_key ed25519 "$HOST_KEY_DIR/ssh_host_ed25519_key"
    generate_host_key rsa "$HOST_KEY_DIR/ssh_host_rsa_key"
    chmod 0600 "$HOST_KEY_DIR"/ssh_host_*_key
    chmod 0644 "$HOST_KEY_DIR"/ssh_host_*_key.pub
}

initialize_gitolite() {
    local config_file="$GIT_HOME/.gitolite/conf/gitolite.conf"

    if [[ -f "$config_file" ]]; then
        return
    fi

    if [[ ! -f "$ADMIN_KEY_PATH" ]]; then
        printf 'gitolite is not initialized and %s is missing\n' "$ADMIN_KEY_PATH" >&2
        return
    fi

    chown git:git "$ADMIN_KEY_PATH"
    chmod 0600 "$ADMIN_KEY_PATH"

    su -s /bin/bash git -c "gitolite setup -pk '$ADMIN_KEY_PATH'"
}

main() {
    ensure_layout
    ensure_host_keys
    initialize_gitolite

    exec /usr/sbin/sshd \
        -D \
        -e \
        -f /etc/ssh/sshd_config \
        -o "HostKey=$HOST_KEY_DIR/ssh_host_ed25519_key" \
        -o "HostKey=$HOST_KEY_DIR/ssh_host_rsa_key" \
        "$@"
}

main "$@"