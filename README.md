# Sentiloop Host

![Version](https://img.shields.io/badge/version-0.1.1-blue)

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

This builds with Docker's layer cache, starts the containers and shows all service
logs. **Press Ctrl+C to stop the containers.** They remain available for the next
start, along with their logs.

## Commands

Run these from the `host` directory.

| Command | What it does |
| --- | --- |
| `make help` | List available commands |
| `make start` | Mac: build and start. Pi: pull configured images and start. Attach logs on both |
| `make stop` | Stop containers without removing them |
| `make build` | Build local images on Mac; skip on Pi |
| `make up` | Start in the background using local images; never build or pull |
| `make update` | Mac: update the existing `cognitive-loop` Git clone. Pi: pull configured images. Leave containers untouched |
| `make restart SERVICE=cognitive-loop` | Restart only that existing container, without rebuilding or recreating it |
| `make exec SERVICE=cognitive-loop` | Open an interactive root shell inside that running container |
| `make down` | Remove containers and networks; keep images and persistent volumes |
| `make provision` | Run Pi provisioning; do nothing on Mac |

For background operation, run `make build` on Mac or `make update` on Pi, then
`make up`. View the current application's logs with:

```sh
docker compose logs cognitive-loop
```

`start` and `up` reuse unchanged containers and recreate them when their image or
configuration changes. Edits made inside a container survive stop/restart, but are
lost when it is recreated or removed with `down`.

On Mac, `update` uses `git pull --ff-only` and refuses uncommitted changes or a
detached HEAD. Update this `host` repository separately.

## Set up a Raspberry Pi

Before provisioning, the Pi needs system Python 3.13 with venv/ensurepip support
(`python3-venv`), the official Debian/Pi APT repositories and keyrings, and kmod.
Run provisioning as root or with working noninteractive `sudo -n`:

```sh
make provision
```

This installs the pinned Docker, Hailo PCIe driver and IMX500 packages, matching
kernel headers and DKMS build tools. It holds the nine verified kernel image/header
packages, loads the Hailo driver, and enables Docker. It does not reboot the Pi.
The exact packages and configuration are in the
[kernel playbook](platforms/raspberry-pi/versions/6.18.34+rpt-rpi-2712.yaml).

Each explicit `make provision` runs Ansible again to apply the desired state.
Successful completion writes `/var/lib/sentiloop/provisioned`. `start` and `up`
provision automatically only when that marker is missing. Your user also needs
Docker daemon access; provisioning does not change group membership.

The Pi runs the private image `ghcr.io/sentiloop-labs/cognitive-loop:latest` by
default. Authenticate to GHCR separately with `docker login ghcr.io`, then run
`make start`. No application source checkout is needed on Pi.

To deploy a specific published version instead:

```sh
COGNITIVE_LOOP_TAG=0.1.1 make start
```

You can also set `COGNITIVE_LOOP_TAG` in an untracked `host/.env` file. Use the same
tag for subsequent `update` and `up` commands; `restart` keeps the existing container.

Pi provisioning and hardware operation still require validation on the actual Pi,
including DKMS builds, Hailo device access and camera capture.

## Tools and configuration

| Tool | Responsibility |
| --- | --- |
| Make | Command interface for development and administration |
| Docker Compose | Build, pull and manage application containers |
| Ansible | Configure the Raspberry Pi locally, without SSH |
| APT | Install Pi packages and resolve their dependencies |

The Pi bootstrap installs `ansible-core==2.20.10` in an isolated environment under
`/opt/sentiloop` only when needed, then reuses it. `uname -r` selects the standalone
playbook in `platforms/raspberry-pi/versions/`.

Compose uses `compose.yaml` for shared service settings, adds
`platforms/raspberry-pi/compose.yaml` on Pi, and adds `compose.build.yaml` for Mac
builds and foreground starts. Local builds use `../cognitive-loop`; Pi uses the
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
