#!/bin/bash
set -euo pipefail

host_config=${1:?Expected host configuration JSON; run make provision}
# Wrap the complete configuration under one namespace without reading config.toml.
extra_vars=$(/usr/bin/python3 -c '
import json, sys
try:
    config = json.loads(sys.argv[1])
except ValueError:
    config = None
if not isinstance(config, dict):
    sys.exit("Host configuration must be a JSON object")
print(json.dumps({"host_config": config}))
' "$host_config")
cd "$(dirname "$0")"
playbook="versions/$(uname -r).yaml"
[ -f "$playbook" ] || { echo "Unsupported kernel: no playbook $playbook" >&2; exit 1; }
bash bootstrap.sh
ansible_version=2.20.10
venv="/opt/sentiloop/ansible-core-$ansible_version"
if ! "$venv/bin/python" -c 'import importlib.metadata, sys; sys.exit(importlib.metadata.version("ansible-core") != sys.argv[1])' "$ansible_version" 2>/dev/null; then
    [ -x "$venv/bin/python" ] || python3 -m venv "$venv"
    "$venv/bin/python" -m pip install --disable-pip-version-check "ansible-core==$ansible_version"
fi
exec "$venv/bin/ansible-playbook" -i localhost, -c local \
    -e ansible_python_interpreter=/usr/bin/python3 --extra-vars "$extra_vars" "$playbook"
