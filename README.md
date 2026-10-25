# host

Host configuration and container orchestration for Sentiloop. This repository
does not produce a Docker image. Supported hosts are Apple Silicon macOS and
Raspberry Pi 5 with Raspberry Pi OS Debian 13 Trixie, ARM64, using a supported
kernel version profile.

Run Make from this directory. `cognitive-loop` is an ordinary independent Git
clone at `../cognitive-loop`, never a submodule.

| Target | macOS | Raspberry Pi OS |
| --- | --- | --- |
| `make start` | Build using Docker cache, start with attached logs | Pull pinned GHCR images, then start with attached logs; no builds |
| `make stop` | Stop containers, preserving their writable filesystems | Same |
| `make provision` | No OS modifications | Recheck and reconcile packages to the selected kernel profile |
| `make build` | Build local service images | Skip; use prebuilt images |
| `make up` | Start existing local images | Provision only if `/var/lib/sentiloop/provisioned` is missing, then start images |
| `make down` | Stop and remove containers and network; retain images and volumes | Same |
| `make update` | Pull `../cognitive-loop` with `git pull --ff-only` | Pull configured GHCR images by digest |
| `make exec SERVICE=name` | Open `/bin/sh` in the running service | Same |
| `make restart SERVICE=name` | Restart only the existing named service container | Same |

`up` never builds or pulls. `update` never restarts or recreates containers.
Mac `start` uses Compose `up --build` with the layer cache; Pi `start` calls
the same pull function as `update` to pull images, then uses `up --no-build --pull never`.
Neither runs `down` before starting. Compose reports missing local images for
`up`; run `make build` on Mac or `make update` on Pi first.
Mac updates refuse dirty repositories and detached HEADs; they never switch
branches or discard changes. Update this host repository separately.

For the normal foreground workflow, run `make start` from this directory.
It follows logs from all services. Native Compose attached mode handles Ctrl+C
by stopping containers gracefully, preserving them and their writable filesystems.
If any service exits, the attached stack stops as well.
`make stop` explicitly stops the stack without removing containers or the network.

The individual build, update and detached `up` commands remain available.
As before, Pi `start` and `up` provision only when the success marker is missing.

Both `start` and `up` let Compose recreate containers when their image or service
configuration changes, and reuse them otherwise. Stop/start and restart preserve
temporary file changes while the same container is retained. Recreation and
`make down` discard container writable filesystems. Images and persistent volumes
are retained; no volume-removal option is used.

Use `make exec SERVICE=cognitive-loop` for an interactive debug shell. It runs
as root inside the container so application files can be inspected and edited;
the application's configured runtime user is unchanged. Exit the shell normally,
then use `make restart SERVICE=cognitive-loop` to restart just that container
with its file changes intact. Neither command builds, pulls or recreates it.
`SERVICE` is required; Compose reports unknown services and unavailable containers.

Compose order is `compose.yaml`, then `platforms/<platform>/compose.yaml` when
present, then `compose.build.yaml` **only for Mac `build` and `start`**. All paths resolve
from the host repository root. Package version profiles are used only by Pi
provisioning; Compose and Mac commands do not depend on them. The Pi override
selects a configured GHCR image and `linux/arm64`; it contains no build context.
The `cognitive-loop` service
currently runs a disposable orchestration smoke test. It prints recognisable
startup/shutdown messages and otherwise waits; it contains no cognitive logic.
Docker Compose validates these files without starting containers:

```sh
docker compose -f compose.yaml -f compose.build.yaml config --quiet
```

For local Mac validation, with Docker Desktop running:

```sh
make start
```

The command builds, starts and displays logs. Press Ctrl+C to stop while retaining
the containers. For separate control of each stage instead:

```sh
make build
make up
docker compose logs cognitive-loop
make stop
```

`make build` uses `../cognitive-loop` to create
`sentiloop/cognitive-loop:host-integration`. Mac ignores `COGNITIVE_LOOP_IMAGE`,
so experimental local builds cannot tag a pinned GHCR image. The shared service
uses the local image name, `pull_policy: never` and `restart: unless-stopped`. `make up` requires
the image to exist locally and never builds or pulls it. When stopped, the process
prints `Sentiloop cognitive-loop integration test stopped cleanly.`
`docker compose logs cognitive-loop` can show startup and shutdown messages
after `make stop`, since the stopped containers and their logs still exist.

For the later Pi deployment, set `COGNITIVE_LOOP_IMAGE` to a published
`ghcr.io/...@sha256:<digest>` ARM64 image using the environment or an untracked
root `.env` file. Run `make start` for the foreground workflow, or `make update`
then `make up` for detached operation. Pi commands use no build overlay and need
no sibling source checkout. The Pi override requires this variable, with no local
image fallback. `start`, `up` and `update` reject floating tags and non-GHCR
references. No final digest is provided until an image is actually published.
`make update` pulls every image in the effective Compose configuration. Docker
reuses cached layers when the image has not changed. `make update` leaves existing
containers untouched; the next `make start` or `make up` applies changed images
through Compose's normal recreation behaviour. GHCR publishing remains a separate task.

Install and run Docker Desktop separately on the Mac. On Pi, provisioning needs
root or working `sudo -n`; it never prompts. The base OS must already provide
Python 3.13 with venv/ensurepip support, the official Debian/Pi APT repositories
and keyrings, kmod and udev. Bootstrap prerequisites such as `python3-venv` must
be installed separately before the first run.

`platforms/raspberry-pi/provision.sh` selects `versions/$(uname -r).yaml` and
fails clearly if that playbook is missing. It installs `ansible-core==2.20.10`
into `/opt/sentiloop/ansible-core-2.20.10` only when needed, reuses the environment
on subsequent runs, and invokes the selected playbook locally without SSH. It uses `/usr/bin/python3` for
Ansible modules. `deb822_repository` manages the official Docker repository and
signing key; its Python dependency and the APT module's Python dependency are
installed by Ansible when needed.

The playbook requires Raspberry Pi 5, Debian 13 Trixie ARM64 and Python 3.13.
Each kernel-named YAML file is a complete, standalone playbook containing its
exact package specifications and tasks. The current playbook is
[6.18.34+rpt-rpi-2712.yaml](platforms/raspberry-pi/versions/6.18.34+rpt-rpi-2712.yaml).
Its APT task lists the exact Docker, standalone Hailo PCIe driver and
IMX500 metapackage pins directly. Matching
kernel headers, DKMS and build tools are installed first. APT resolves dependencies;
removals and unattended downgrades are refused, and recommended packages are not
added. No global upgrade, kernel replacement, Python replacement or blanket APT
pinning is performed. Normal compatible maintenance updates remain available.

After installation, `modprobe hailo1x_pci` activates the Hailo driver. PCIe binding,
device-node availability and camera functionality are tested separately on the Pi.
Driver builds belong to the official packages; no manual driver installation or
Hailo inference software is added. Ansible enables and starts Docker, then writes
`/var/lib/sentiloop/provisioned` only after all tasks succeed. Explicit provisioning
always runs Ansible and invalidates earlier success after host/profile selection;
`make start` and `make up` retain their existing marker-based startup shortcut.

Actual Pi testing is still required for bootstrap, repository/package availability,
DKMS builds, repeat provisioning, driver initialization and camera capture. A reboot
may be needed for hardware changes; provisioning does not reboot. Container hardware
access, Yukon deployment, GHCR publishing and CI/CD remain separate work. Authenticate
private GHCR access separately before Pi image updates. Docker commands require
existing daemon access; provisioning does not change user/group membership.
