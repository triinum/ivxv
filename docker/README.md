# Docker packaging for IVXV microservices

Each deployable service has its own `Dockerfile` in its top-level directory.
Shared build helpers live here:

- `go-build.sh` — codegen + compile for Go collector services
- `gen-go-dockerfiles.sh` — regenerates the Go service Dockerfiles
- `java-app.Dockerfile` — reference recipe for offline Java apps
- `Makefile` — `make -C docker all` / `online` / `offline`

See `/SERVICES.md` for the service map and independent-development workflow.
