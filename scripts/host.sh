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
if [ "$platform" = macos ] && { [ "$command" = build ] || [ "$command" = start ]; }; then
    compose+=(-f compose.build.yaml)
fi

# Prepare the detected host: macOS needs no provisioning; Pi runs its provisioning
# script as root, using non-interactive sudo when the caller is not already root.
provision() {
    if [ "$platform" = macos ]; then
        echo 'macOS provisioning: nothing to do. Manage Docker Desktop separately.'
    elif [ "$(id -u)" = 0 ]; then
        bash platforms/raspberry-pi/provision.sh
    else
        sudo -n bash platforms/raspberry-pi/provision.sh
    fi
}

# Ask Compose to pull every service image explicitly, leaving containers untouched.
pull_images() {
    "${compose[@]}" pull --policy always
}

case "$command" in
    start|up)
        if [ "$platform" = raspberry-pi ]; then
            [ -f /var/lib/sentiloop/provisioned ] || provision
        fi
        if [ "$command" = up ]; then
            exec "${compose[@]}" up -d --no-build --pull never
        elif [ "$platform" = macos ]; then
            exec env COMPOSE_MENU=false "${compose[@]}" up --build --abort-on-container-exit
        else
            pull_images
            exec env COMPOSE_MENU=false "${compose[@]}" up --no-build --pull never --abort-on-container-exit
        fi
        ;;
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
