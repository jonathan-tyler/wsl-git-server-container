#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ADMIN_PRIVATE_KEY="${ADMIN_PRIVATE_KEY:-}"
CLIENT_KEY_NAME="${CLIENT_KEY_NAME:-}"
CLIENT_KEY_PATH="${CLIENT_KEY_PATH:-}"

load_config

while [[ $# -gt 0 ]]; do
    case "$1" in
        --admin-key)
            ADMIN_PRIVATE_KEY="$2"
            shift 2
            ;;
        --key-name)
            CLIENT_KEY_NAME="$2"
            shift 2
            ;;
        --key-file)
            CLIENT_KEY_PATH="$2"
            shift 2
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$ADMIN_PRIVATE_KEY" || -z "$CLIENT_KEY_NAME" || -z "$CLIENT_KEY_PATH" ]]; then
    printf 'Usage: %s --admin-key /path/to/admin --key-name name --key-file /path/to/client.pub\n' "$0" >&2
    exit 1
fi

if [[ ! -f "$ADMIN_PRIVATE_KEY" ]]; then
    printf 'Admin private key not found: %s\n' "$ADMIN_PRIVATE_KEY" >&2
    exit 1
fi

if [[ ! -f "$CLIENT_KEY_PATH" ]]; then
    printf 'Client public key not found: %s\n' "$CLIENT_KEY_PATH" >&2
    exit 1
fi

GIT_SSH_COMMAND="ssh -i '$ADMIN_PRIVATE_KEY' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -p '$LISTEN_PORT'" \
    git clone "ssh://git@${ADMIN_CLONE_HOST}/gitolite-admin" "$TMP_DIR/gitolite-admin" >/dev/null 2>&1

install -m 0644 "$CLIENT_KEY_PATH" "$TMP_DIR/gitolite-admin/keydir/${CLIENT_KEY_NAME}.pub"

git -C "$TMP_DIR/gitolite-admin" add "keydir/${CLIENT_KEY_NAME}.pub"

if git -C "$TMP_DIR/gitolite-admin" diff --cached --quiet; then
    printf 'Key already present: %s\n' "$CLIENT_KEY_NAME"
    exit 0
fi

git -C "$TMP_DIR/gitolite-admin" commit -m "Add key ${CLIENT_KEY_NAME}" >/dev/null
GIT_SSH_COMMAND="ssh -i '$ADMIN_PRIVATE_KEY' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -p '$LISTEN_PORT'" \
    git -C "$TMP_DIR/gitolite-admin" push >/dev/null

printf 'Added client key: %s\n' "$CLIENT_KEY_NAME"
printf 'Repo permissions still need to be managed in gitolite-admin config.\n'