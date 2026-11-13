# IVXV services and Dockerfile structure

Each subdirectory under `services/` is an independently developed microservice
or offline tool. The **Dockerfile always lives in the same directory** as that
service’s source.

```text
services/
  <name>/
    Dockerfile          # co-located with the service
    go.mod | …          # service source / module
    …
docker/                 # shared build helpers only (not per-service Dockerfiles)
docker-compose.yml      # local multi-service wiring
```

See also `/SERVICES.md` (service map) and `/docker/README.md` (build helpers).

## Layout rule

| Path | Role |
|------|------|
| `services/<name>/Dockerfile` | Image definition for that service |
| `services/<name>/` (rest) | Source, tests, service-local config |
| `docker/go-build.sh` | Shared Go codegen + compile used by Go Dockerfiles |
| `docker/gen-go-dockerfiles.sh` | Regenerates Go collector Dockerfiles |
| `docker/Makefile` | `make -C docker all\|online\|offline` |

Do **not** put per-service Dockerfiles under `docker/`. That directory is only
for shared helpers.

## Service catalog

### Online collector microservices (Go / Python)

| Service | Dockerfile | Image | Runtime notes |
|---------|------------|-------|---------------|
| proxy | `services/proxy/Dockerfile` | `ivxv/proxy` | HAProxy + Go controller; port 443 |
| choices | `services/choices/Dockerfile` | `ivxv/choices` | Go; needs `sessionstatus/api` |
| voting | `services/voting/Dockerfile` | `ivxv/voting` | Go; needs `sessionstatus/api` |
| verification | `services/verification/Dockerfile` | `ivxv/verification` | Go; needs `sessionstatus/api` |
| storage | `services/storage/Dockerfile` | `ivxv/storage` | Go; works with etcd |
| sessionstatus | `services/sessionstatus/Dockerfile` | `ivxv/sessionstatus` | Go; includes `api/` module |
| mid | `services/mid/Dockerfile` | `ivxv/mid` | Mobile-ID helper |
| smartid | `services/smartid/Dockerfile` | `ivxv/smartid` | Smart-ID helper |
| webeid | `services/webeid/Dockerfile` | `ivxv/webeid` | Web eID helper |
| votesorder | `services/votesorder/Dockerfile` | `ivxv/votesorder` | Vote order feed |
| xroad-service | `services/xroad-service/Dockerfile` | `ivxv/xroad-service` | Standalone Go module |
| collector-admin | `services/collector-admin/Dockerfile` | `ivxv/collector-admin` | Python admin daemon |

### Offline applications (Java)

| Application | Dockerfile | Image |
|-------------|------------|-------|
| key | `services/key/Dockerfile` | `ivxv/key` |
| processor | `services/processor/Dockerfile` | `ivxv/processor` |
| auditor | `services/auditor/Dockerfile` | `ivxv/auditor` |

## Dockerfile patterns

### Go collector services

Multi-stage build from the **repository root** context:

1. **builder** (`golang:1.23-bookworm`) copies `core/`, `common/collector`,
   codegen tools, and `services/<name>/`, then runs `ivxv-go-build <name>`.
2. **runtime** (`debian:bookworm-slim`) copies binaries to `/usr/bin` and runs
   as user `ivxv` (proxy runs as root to manage HAProxy).

Shared dependencies copied into the image as needed:

- always: `core`, `common/collector`, `common/tools/go`, `scripts/goimports.sh`
- when required: `services/sessionstatus/api`

### xroad-service

Self-contained Go module (no `common/collector`). Builds `./cmd` only.

### collector-admin

Python image; installs the package from repo-root `setup.py` with
`package_dir` pointing at `services/collector-admin`.

### Java offline tools

Multi-stage Temurin 21 build: download Gradle in-container, build
`installDist`, ship the JRE runtime with `/opt/ivxv/<app>/bin` on `PATH`.

## Build commands

Always run from the **repository root** (shared modules use relative
`replace` paths and Docker `COPY` paths from root):

```bash
# one service
docker build -f services/voting/Dockerfile -t ivxv/voting .

# all services
make docker
# or
make -C docker online    # collector microservices
make -C docker offline   # key / processor / auditor
```

Compose (same Dockerfiles):

```bash
docker compose build
docker compose build voting
```

## Configuration at runtime

Most collector images expect IVXV configuration containers under `/etc/ivxv`
(trust, election, technical, sensitive instance material).

`xroad-service` defaults to `/etc/xroad-service/xroad-service.json`.

Without that material the process exits after configuration checks — expected
for an empty mount.

## Regenerating Go Dockerfiles

After changing the shared Go image recipe:

```bash
bash docker/gen-go-dockerfiles.sh
```

This rewrites `services/<go-service>/Dockerfile` for the collector Go set.
Hand-maintained Dockerfiles (`xroad-service`, `collector-admin`, Java apps)
are not touched by that script.
