# host

Host configuration and container orchestration for Sentiloop. This repository
does not produce a Docker image. Supported hosts are Apple Silicon macOS and
64-bit Raspberry Pi OS on Raspberry Pi hardware.

Run Make from this directory. `cognitive-loop` is an ordinary independent Git
clone at `../cognitive-loop`, never a submodule.

| Target | macOS | Raspberry Pi OS |
| --- | --- | --- |
| `make provision` | No operation | Fail clearly: full provisioning pending Pi inspection |
| `make build` | Build local service images | Skip; use prebuilt images |
| `make up` | Start existing local images | Blocked until full provisioning is implemented |
| `make down` | Stop containers | Stop containers |
| `make update` | Pull `../cognitive-loop` with `git pull --ff-only` | Pull configured GHCR images by digest |

`up` never builds or pulls. `update` does not restart services or build images.
Mac updates refuse dirty repositories and detached HEADs; they never switch
branches or discard changes. Update this host repository separately.

`compose.yaml` owns shared service configuration. `compose.build.yaml` is the
Mac build overlay. Both service maps are currently empty because cognitive-loop
has no Dockerfile. `build` and `up` fail clearly until runnable services exist;
`down` and Pi `update` have nothing to do. Docker Compose validates these files
without starting containers:

```sh
docker compose --env-file versions.env -f compose.yaml -f compose.build.yaml config --quiet
```

Before adding cognitive-loop, provide its Dockerfile and runtime contract in
its own repository. Then add shared configuration in `compose.yaml`, and a
`../cognitive-loop` build context, local image name and `pull_policy: never`
in the build overlay. Pi image references must use `ghcr.io/...@sha256:<digest>`;
`up` and `update` reject unpinned Pi references. No GHCR image is assumed to exist.

Install and run Docker Desktop separately on the Mac. **Full Raspberry Pi
provisioning is pending** inspection of the actual Pi and establishment of its
exact OS, kernel, Docker, Hailo and camera package versions and package sources.
The runtime pins in `versions.env` remain unset and are not a complete inventory.
No packages, drivers, hardware configuration or Yukon software are installed or
upgraded. Yukon software deployment remains outside OS provisioning.

Pi `provision` and `up` fail non-interactively without changing the system.
No success marker is created, and existing markers cannot bypass this pending
state. Marker creation and reuse must only be enabled when the complete,
idempotent, pinned provisioning process genuinely works. Filling in version
values alone does not enable provisioning.
Private GHCR image access must be authenticated separately before Pi updates.
