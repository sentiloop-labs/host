#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source scripts/platform.sh
[ "$(detect_platform)" = raspberry-pi ] || {
    echo 'This provisioning script requires Raspberry Pi OS.' >&2
    exit 1
}

echo 'Raspberry Pi provisioning is pending inspection of the actual Pi.' >&2
echo 'Establish exact OS, kernel, Docker, Hailo and camera package versions before implementation.' >&2
echo 'Nothing has been installed or upgraded; no provisioning marker has been created.' >&2
exit 1
