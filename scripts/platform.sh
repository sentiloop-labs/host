#!/bin/bash
# Sourced by host commands; no platform override is accepted.
detect_platform() {
    case "$(uname -s):$(uname -m)" in
        Darwin:arm64)
            printf '%s\n' macos
            ;;
        Linux:aarch64)
            if [ -r /proc/device-tree/model ] &&
                grep -q '^Raspberry Pi 5 ' /proc/device-tree/model &&
                [ -r /etc/os-release ] &&
                grep -Eq '^ID=(raspbian|"raspbian")$|^ID=(debian|"debian")$' /etc/os-release &&
                [ -r /etc/rpi-issue ] &&
                grep -Eq '^VERSION_CODENAME=(trixie|"trixie")$' /etc/os-release; then
                printf '%s\n' raspberry-pi
            else
                echo 'Supported Linux host: Raspberry Pi 5, Raspberry Pi OS Trixie ARM64.' >&2
                return 1
            fi
            ;;
        *)
            echo 'Supported hosts: Apple Silicon macOS and Raspberry Pi 5 with Raspberry Pi OS Trixie ARM64.' >&2
            return 1
            ;;
    esac
}
