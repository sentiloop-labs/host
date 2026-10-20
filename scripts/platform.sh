#!/bin/bash
# Sourced by host commands; no platform override is accepted.
detect_platform() {
    case "$(uname -s):$(uname -m)" in
        Darwin:arm64)
            printf '%s\n' macos
            ;;
        Linux:aarch64)
            if [ -r /proc/device-tree/model ] &&
                grep -q '^Raspberry Pi' /proc/device-tree/model &&
                [ -r /etc/os-release ] &&
                grep -Eq '^ID=(raspbian|"raspbian")$|^ID=(debian|"debian")$' /etc/os-release &&
                [ -r /etc/rpi-issue ]; then
                printf '%s\n' raspberry-pi
            else
                echo 'Supported Linux host: 64-bit Raspberry Pi OS on Raspberry Pi hardware.' >&2
                return 1
            fi
            ;;
        *)
            echo 'Supported hosts: Apple Silicon macOS and 64-bit Raspberry Pi OS.' >&2
            return 1
            ;;
    esac
}
