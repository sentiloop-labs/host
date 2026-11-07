# Sentiloop Host

![Version](https://img.shields.io/badge/version-0.4.0-blue)

Set up a Sentiloop host and run its application containers through Docker Compose.
Use the same Make commands on Mac and Raspberry Pi; the scripts detect the platform.

## Supported platforms

| Platform | Application images | Host setup |
| --- | --- | --- |
| Apple Silicon macOS | Built locally from sibling repositories | Install and run Docker Desktop separately |
| Raspberry Pi 5, Raspberry Pi OS 64-bit, Debian 13 Trixie | Pulled from GHCR; `latest` by default or a chosen version tag | Provisioned locally with Ansible |

The supported Pi kernel is `6.18.34+rpt-rpi-2712`. Other kernels and platforms
are rejected.

The current application is a temporary `cognitive-loop` smoke test: it prints a
startup message, stays running and shuts down cleanly. It has no cognitive logic yet.

## Get started on Mac

Keep the two independent Git repositories beside each other:

```text
sentiloop/
├── host/
└── cognitive-loop/
```

With Docker Desktop running, open a terminal in `host` and run:

```sh
make start
```

This builds with Docker's layer cache, starts the containers in the background and
returns to the prompt. They keep running when you close the terminal.

For attached debugging with combined service logs, use `make start-logs` instead.
**Press Ctrl+C to stop the containers in this mode.**

## Commands

Run these from the `host` directory.

| Command | What it does |
| --- | --- |
| `make help` | List available commands |
| `make start` | Mac: build; Pi: pull configured images. Start detached on both |
| `make start-logs` | Same preparation as `start`, then start attached with combined logs; Ctrl+C stops containers |
| `make logs` | Follow all service logs with service prefixes; Ctrl+C closes only the viewer |
| `make stop` | Stop containers without removing them |
| `make build` | Build local images on Mac; skip on Pi |
| `make up` | Start in the background using local images; never build or pull |
| `make update` | Mac: update the existing `cognitive-loop` Git clone. Pi: pull configured images. Leave containers untouched |
| `make restart SERVICE=cognitive-loop` | Restart only that existing container, without rebuilding or recreating it |
| `make exec SERVICE=cognitive-loop` | Open an interactive root shell inside that running container |
| `make down` | Remove containers and networks; keep images and persistent volumes |
| `make provision` | Run Pi provisioning; do nothing on Mac |

Use `make start` for normal background operation. To prepare images separately,
run `make build` on Mac or `make update` on Pi, then `make up`.
View combined stdout/stderr logs from every service with:

```sh
make logs
```

Leaving `make logs` does not stop or remove containers. `make start-logs` runs
Compose in the foreground directly; it stops the stack if any service exits.

`start`, `start-logs` and `up` reuse unchanged containers and recreate them when
their image or configuration changes. Edits made inside a container survive
stop/restart, but are lost when it is recreated or removed with `down`.

On Mac, `update` uses `git pull --ff-only` and refuses uncommitted changes or a
detached HEAD. Update this `host` repository separately.

## Raspberry Pi reboot behaviour

Provision the Pi and start the application explicitly the first time. Docker is
enabled at boot, and services use `restart: unless-stopped`, so subsequent Pi
reboots restore previously running containers using their existing images and
configuration. No separate Compose boot service is needed.

- `make stop` intentionally keeps containers stopped across reboots. Run
  `make start` or `make up` to resume them.
- `make down` removes containers, so a reboot cannot restore them. Start them
  explicitly again to recreate them.
- Boot does not pull images, build, provision, update source code or reconcile
  Compose changes. Use `make start` explicitly to build/pull and apply changes.

## Set up a Raspberry Pi

Start from the supported Raspberry Pi OS with system Python 3.13 and the official
Debian/Pi APT repositories and keyrings. Before cloning this repository, download
and run its standalone bootstrap using Python's standard library; Git, curl and
an existing clone are not required. Run as root or with working noninteractive
`sudo -n` (omit `sudo -n` when running as root):

```sh
python3 - <<'PY'
from pathlib import Path
from urllib.request import urlopen

url = "https://raw.githubusercontent.com/sentiloop-labs/host/main/platforms/raspberry-pi/bootstrap.sh"
with urlopen(url, timeout=30) as response:
    Path("sentiloop-bootstrap.sh").write_bytes(response.read())
PY
sudo -n bash sentiloop-bootstrap.sh
```

The bootstrap installs pinned Git, Vim and Make, plus Python venv support and
kmod. Matching packages are skipped by APT; unavailable pins or required
downgrades fail rather than silently substituting versions. The download URL
requires the bootstrap to have been published on `main`.

Then clone the public repository over HTTPS and provision it:

```sh
git clone https://github.com/sentiloop-labs/host.git
cd host
make provision
```

By default this installs the pinned Docker, Hailo PCIe driver and IMX500 packages,
matching kernel headers and DKMS build tools. It holds the nine verified kernel
image/header packages, loads the selected Hailo driver, and enables Docker. The
provisioning entrypoint reruns the same bootstrap before starting Ansible; Vim
installation belongs only to that script. Ansible installs `i2c-tools` at its
verified exact package version.
Existing Docker, Hailo and IMX500 package pins remain unchanged.

Provisioning persistently enables GPIO I²C in `/boot/firmware/config.txt` and
loads `i2c-dev` at boot through `/etc/modules-load.d/sentiloop-i2c.conf`. Existing
boot settings and conditional sections are preserved. Reboot the Pi after first
applying these I²C settings, or after changing them, before expecting `/dev/i2c-1`
to be available. Provisioning does not reboot, scan the bus or move hardware.
The platform package pins and configuration remain in the
[kernel playbook](platforms/raspberry-pi/versions/6.18.34+rpt-rpi-2712.yaml).
Device pins, compatibility requirements and activation live in the reusable
device library: [hailo-10h.yaml](devices/hailo-10h.yaml) and
[imx500.yaml](devices/imx500.yaml). Both devices currently support only the
validated Pi 5, Trixie ARM64, kernel `6.18.34+rpt-rpi-2712`, Python 3.13 profile.

Select devices in the host application configuration, [config.toml](config.toml):

```toml
enabled_devices = ["hailo-10h", "imx500"]
```

These are the only supported identifiers, and both are enabled by default.
Use `enabled_devices = []` for platform-only provisioning. Missing or invalid
configuration, unknown devices and duplicate entries fail explicitly. Devices
are processed in the fixed order shown above. Hailo alone contributes matching
kernel headers, DKMS and build-essential; these are not platform requirements.
Disabling a device does not uninstall packages or undo existing configuration.
After editing the list, explicitly rerun `make provision`.

Provisioning collects and validates platform and selected-device requirements,
then installs them together through one Ansible APT task after applying kernel
holds and preparing repositories. APT resolves dependencies and runs package
maintainer scripts during installation; this is not a rollback-safe transaction.
After installation succeeds, Ansible configures the shell alias and I²C, activates
Hailo if selected, then configures the Docker service and user access.

Each explicit `make provision` runs Ansible again to apply the desired state.
Successful completion writes `/var/lib/sentiloop/provisioned`. `start`,
`start-logs` and `up` provision automatically only when that marker is missing.

Run `make provision` from your trusted administrator account: provisioning uses
`SUDO_USER` to add that account to the `docker` group, preserving its other groups.
Log out and reconnect afterwards so the new membership takes effect, then run
`make start` without sudo. Direct root runs without a non-root `SUDO_USER` skip
this membership change. Docker group membership grants root-equivalent access.

The Pi runs the private image `ghcr.io/sentiloop-labs/cognitive-loop` with the tag
set in [config.toml](config.toml), `latest` by default. Authenticate to GHCR
separately with `docker login ghcr.io`, then run `make start`. No application
source checkout is needed on Pi.

To deploy a specific published version persistently, set it in `config.toml`:

```toml
[image_tags]
cognitive_loop = "0.1.1"
```

`start`, `start-logs`, `up` and `update` all use this tag. For a one-off debugging
or rollback run, a nonempty environment value overrides it for that command:

```sh
COGNITIVE_LOOP_TAG=0.1.1 make start
```

`config.toml` replaces `host/.env` as the persistent tag source; the resolved tag
is exported to Compose and takes precedence over `.env`. `restart` keeps the
existing container. Invalid tags fail before Compose runs.

`image_tags` selects the published Pi image only. Mac always builds and runs the
local `sentiloop/cognitive-loop:host-integration` image and does not read
`config.toml`.

Pi provisioning and hardware operation still require validation on the actual Pi,
including DKMS builds, Hailo device access and camera capture.

## Tools and configuration

[config.toml](config.toml) is the only host application configuration. On Pi,
each configuration-consuming command (`provision`, `start`, `start-logs`, `up`,
`update`) reads it once through `scripts/config.py`, with system Python. Compose
receives only the explicitly mapped `COGNITIVE_LOOP_TAG`; provisioning receives
the complete configuration as `host_config`. Platform playbooks and device tasks
are reusable implementations and never read `config.toml` themselves. `stop`,
`down`, `logs`, `restart`, `exec` and all Mac commands do not read it.

| Tool | Responsibility |
| --- | --- |
| Make | Command interface for development and administration |
| Docker Compose | Build, pull and manage application containers |
| Ansible | Configure the Raspberry Pi locally, without SSH |
| APT | Install Pi packages and resolve their dependencies |

The Pi bootstrap installs `ansible-core==2.20.10` in an isolated environment under
`/opt/sentiloop` only when needed, then reuses it. `uname -r` selects the versioned
platform playbook in `platforms/raspberry-pi/versions/`.

Compose uses `compose.yaml` for shared service settings, adds
`platforms/raspberry-pi/compose.yaml` on Pi, and adds `compose.build.yaml` for Mac
`build`, `start` and `start-logs`. Local builds use `../cognitive-loop`; Pi uses the
published GHCR image with `latest` or the chosen version tag.

## Versioning

Choose a version bump locally, alongside any uncommitted code changes:

```sh
bump-my-version bump patch
bump-my-version bump minor
bump-my-version bump major
```

Use one command for the intended change, then review and commit it yourself.
Bump My Version updates `pyproject.toml` and the badge without creating commits or
tags. Pushes to `main` create the numeric version tag on that commit if it does
not already exist. No GitHub Releases or Docker images are published by this workflow.
