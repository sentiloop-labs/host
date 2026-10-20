#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/platform.sh
platform=$(detect_platform)
command=${1:?Expected a Make target}

compose=(docker compose --project-name sentiloop --env-file versions.env -f compose.yaml)
if [ "$platform" = macos ]; then
    compose+=(-f compose.build.yaml)
fi

provision() {
    if [ "$platform" = macos ]; then
        echo 'macOS provisioning: nothing to do. Manage Docker Desktop separately.'
    else
        bash platforms/raspberry-pi/provision.sh
    fi
}

services() {
    "${compose[@]}" config --services
}

require_services() {
    configured_services=$(services)
    if [ -z "$configured_services" ]; then
        echo 'No runnable services yet. cognitive-loop needs a Dockerfile before Compose wiring can be added.' >&2
        exit 1
    fi
}

validate_images() {
    images=$("${compose[@]}" config --images)
    while IFS= read -r image; do
        [ -n "$image" ] || continue
        if ! printf '%s\n' "$image" | grep -Eq '^ghcr\.io/[^[:space:]@]+@sha256:[0-9a-f]{64}$'; then
            echo "Refusing unpinned or non-GHCR image: $image" >&2
            exit 1
        fi
    done <<< "$images"
}

case "$command" in
    provision) provision ;;
    build)
        if [ "$platform" = raspberry-pi ]; then
            echo 'Raspberry Pi uses prebuilt images; build skipped.'
        else
            require_services
            "${compose[@]}" build
        fi
        ;;
    up)
        if [ "$platform" = raspberry-pi ]; then
            # Do not trust markers from runtime-only verification. Full
            # provisioning must be implemented before marker reuse is enabled.
            provision
            validate_images
        fi
        require_services
        "${compose[@]}" up -d --no-build --pull never
        ;;
    down)
        configured_services=$(services)
        if [ -n "$configured_services" ]; then
            "${compose[@]}" down
        else
            echo 'No services configured.'
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
            validate_images
            if [ -z "$images" ]; then
                echo 'No pinned service images configured; nothing to pull.'
                exit 0
            fi
            "${compose[@]}" pull --policy always
        fi
        ;;
    *) echo "Unknown target: $command" >&2; exit 1 ;;
esac
