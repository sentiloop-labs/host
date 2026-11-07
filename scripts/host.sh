#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/platform.sh
platform=$(detect_platform)
command=${1:?Expected a Make target}

compose=(docker compose --project-name sentiloop --project-directory "$PWD" -f compose.yaml)
if [ -f "platforms/$platform/compose.yaml" ]; then
    compose+=(-f "platforms/$platform/compose.yaml")
fi
if [ "$platform" = macos ] && { [ "$command" = build ] || [ "$command" = start ] || [ "$command" = start-logs ]; }; then
    compose+=(-f compose.build.yaml)
fi

python=/usr/bin/python3

# Print one field of the captured snapshot: strings raw, other values as JSON.
snapshot_get() {
    printf '%s' "$snapshot" | "$python" -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1:]:
    value = value[key]
print(value if isinstance(value, str) else json.dumps(value))
' "$@"
}

# Read config.toml once per command; every consumer uses this snapshot.
load_config() {
    snapshot=$("$python" scripts/config.py)
    host_config=$(snapshot_get config)
    COGNITIVE_LOOP_TAG=$(snapshot_get compose_env COGNITIVE_LOOP_TAG)
    export COGNITIVE_LOOP_TAG
}

# Prepare the detected host: macOS needs no provisioning; Pi runs its provisioning
# script as root, using non-interactive sudo when the caller is not already root.
# The configuration is passed as an argument because sudo drops custom variables.
provision() {
    if [ "$platform" = macos ]; then
        echo 'macOS provisioning: nothing to do. Manage Docker Desktop separately.'
    elif [ "$(id -u)" = 0 ]; then
        bash platforms/raspberry-pi/provision.sh "$host_config"
    else
        sudo -n bash platforms/raspberry-pi/provision.sh "$host_config"
    fi
}

if [ "$platform" = raspberry-pi ]; then
    case "$command" in
        start|start-logs|up|update|provision) load_config ;;
    esac
fi

# Ask Compose to pull every service image explicitly, leaving containers untouched.
pull_images() {
    "${compose[@]}" pull --policy always
}

case "$command" in
    start|start-logs|up)
        if [ "$platform" = raspberry-pi ]; then
            [ -f /var/lib/sentiloop/provisioned ] || provision
        fi
        if [ "$command" = up ]; then
            exec "${compose[@]}" up -d --no-build --pull never
        fi
        if [ "$command" = start-logs ]; then
            start_options=(--abort-on-container-exit)
        else
            start_options=(-d)
        fi
        if [ "$platform" = macos ]; then
            start_options+=(--build)
        else
            pull_images
            start_options+=(--no-build --pull never)
        fi
        exec env COMPOSE_MENU=false "${compose[@]}" up "${start_options[@]}"
        ;;
    logs) exec "${compose[@]}" logs --follow ;;
    provision) provision ;;
    build)
        if [ "$platform" = raspberry-pi ]; then
            echo 'Raspberry Pi uses prebuilt images; build skipped.'
        else
            exec "${compose[@]}" build
        fi
        ;;
    down|stop) exec "${compose[@]}" "$command" ;;
    exec|restart)
        service=${SERVICE:?Specify SERVICE, e.g. SERVICE=cognitive-loop}
        if [ "$command" = exec ]; then
            exec "${compose[@]}" exec --user root "$service" /bin/sh
        else
            exec "${compose[@]}" restart --no-deps "$service"
        fi
        ;;
    update)
        if [ "$platform" = macos ]; then
            repo=../cognitive-loop
            [ -d "$repo/.git" ] || { echo "Missing sibling Git clone: $repo" >&2; exit 1; }
            [ -z "$(git -C "$repo" status --porcelain)" ] || {
                echo "Refusing to update $repo: uncommitted changes exist." >&2; exit 1;
            }
            git -C "$repo" symbolic-ref -q HEAD >/dev/null || {
                echo "Refusing to update $repo: detached HEAD." >&2; exit 1;
            }
            git -C "$repo" pull --ff-only
        else
            pull_images
        fi
        ;;
    *) echo "Unknown target: $command" >&2; exit 1 ;;
esac
