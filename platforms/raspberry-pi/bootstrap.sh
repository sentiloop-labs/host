#!/bin/bash
set -euo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive

fail() { echo "Bootstrap failed: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'Run as root or with sudo -n.'
[ "$(uname -sm)" = 'Linux aarch64' ] || fail 'Raspberry Pi OS ARM64 is required.'
[ "$(dpkg --print-architecture)" = arm64 ] || fail 'ARM64 userspace is required.'
[ -r /etc/rpi-issue ] && grep -q '^Raspberry Pi 5 ' /proc/device-tree/model ||
    fail 'Raspberry Pi 5 with Raspberry Pi OS is required.'
source /etc/os-release
[[ "$ID" = debian || "$ID" = raspbian ]] &&
    [ "$VERSION_ID" = 13 ] && [ "$VERSION_CODENAME" = trixie ] ||
    fail 'Raspberry Pi OS Debian 13 Trixie is required.'
[ "$(uname -r)" = '6.18.34+rpt-rpi-2712' ] || fail 'Unsupported kernel.'
[[ "$(/usr/bin/python3 --version)" = 'Python 3.13.'* ]] || fail 'System Python 3.13 is required.'

# APT skips matching packages and refuses removals or unattended downgrades.
apt-get -o APT::Update::Error-Mode=any update
apt-get --yes --no-remove --no-install-recommends -o Dpkg::Options::=--force-confold install \
    git=1:2.47.3-0+deb13u1 vim=2:9.1.1230-2+deb13u1 make=4.4.1-2 python3-venv kmod
