"""Read and validate host/config.toml, then print one JSON snapshot.

Output: {"config": <complete application configuration>,
         "compose_env": {"COGNITIVE_LOOP_TAG": <resolved tag>}}

A nonempty COGNITIVE_LOOP_TAG environment variable overrides
image_tags.cognitive_loop. Unrelated configuration fields are preserved.
"""

import datetime
import json
import os
import re
import sys
import tomllib
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parent.parent / "config.toml"
DEVICE_ID = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
IMAGE_TAG = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}")
TEMPLATE_MARKERS = ("{{", "{%", "{#")


def fail(message):
    print(f"config.toml: {message}", file=sys.stderr)
    sys.exit(1)


def check_values(value, where):
    """Reject values that are not plain JSON data or look like templates."""
    if isinstance(value, dict):
        for key, item in value.items():
            check_values(key, where)
            check_values(item, f"{where}.{key}" if where else key)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            check_values(item, f"{where}[{index}]")
    elif isinstance(value, str):
        if any(marker in value for marker in TEMPLATE_MARKERS):
            fail(f"{where or 'key'}: template markers are not allowed")
    elif isinstance(value, (datetime.date, datetime.time)):
        fail(f"{where}: dates and times are not supported")


def require_tag(value, source):
    if not isinstance(value, str) or not IMAGE_TAG.fullmatch(value):
        fail(f"{source} must be a valid image tag, e.g. latest or 0.1.1")
    return value


def load():
    try:
        with CONFIG_PATH.open("rb") as file:
            config = tomllib.load(file)
    except OSError as error:
        fail(f"cannot read {CONFIG_PATH}: {error.strerror}")
    except tomllib.TOMLDecodeError as error:
        fail(f"invalid TOML: {error}")

    check_values(config, "")

    devices = config.get("enabled_devices")
    if not isinstance(devices, list):
        fail("enabled_devices must be a list (use [] for platform only)")
    for device in devices:
        if not isinstance(device, str) or not DEVICE_ID.fullmatch(device):
            fail(f"invalid device identifier: {device!r}")
    if len(set(devices)) != len(devices):
        fail("enabled_devices must not contain duplicates")

    image_tags = config.get("image_tags")
    if not isinstance(image_tags, dict):
        fail("missing [image_tags] table")
    tag = require_tag(image_tags.get("cognitive_loop"), "image_tags.cognitive_loop")

    override = os.environ.get("COGNITIVE_LOOP_TAG", "")
    if override:
        tag = require_tag(override, "COGNITIVE_LOOP_TAG")

    return {"config": config, "compose_env": {"COGNITIVE_LOOP_TAG": tag}}


if __name__ == "__main__":
    try:
        print(json.dumps(load(), allow_nan=False))
    except ValueError:
        fail("numbers must be finite")
