# Docker build helpers

Shared helpers for building service images.

**Per-service Dockerfiles are not here.** They live next to each service:

`services/<name>/Dockerfile`

See **`services/README.md`** for the full Dockerfile structure, catalog, and
build patterns.

## Contents of this directory

| File | Purpose |
|------|---------|
| `go-build.sh` | Codegen + compile for Go collector services (used inside Dockerfiles) |
| `gen-go-dockerfiles.sh` | Regenerates Go collector Dockerfiles under `services/` |
| `Makefile` | `make -C docker all` / `online` / `offline` |

## Quick build

From repository root:

```bash
docker build -f services/voting/Dockerfile -t ivxv/voting .
make -C docker all
```
