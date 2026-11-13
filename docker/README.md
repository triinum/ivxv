# Docker build helpers

Shared helpers for building service images. **Per-service Dockerfiles live next
to each service** under `services/<name>/Dockerfile` — not here.

- `go-build.sh` — codegen + compile for Go collector services
- `gen-go-dockerfiles.sh` — regenerates Go Dockerfiles under `services/`
- `Makefile` — `make -C docker all` / `online` / `offline`

See `/SERVICES.md` for the service map.
