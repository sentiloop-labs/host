#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
playbook="versions/$(uname -r).yaml"
[ -f "$playbook" ] || { echo "Unsupported kernel: no playbook $playbook" >&2; exit 1; }
ansible_version=2.20.10
venv="/opt/sentiloop/ansible-core-$ansible_version"
if ! "$venv/bin/python" -c 'import importlib.metadata, sys; sys.exit(importlib.metadata.version("ansible-core") != sys.argv[1])' "$ansible_version" 2>/dev/null; then
    [ -x "$venv/bin/python" ] || python3 -m venv "$venv"
    "$venv/bin/python" -m pip install --disable-pip-version-check "ansible-core==$ansible_version"
fi
exec "$venv/bin/ansible-playbook" -i localhost, -c local \
    -e ansible_python_interpreter=/usr/bin/python3 "$playbook"
