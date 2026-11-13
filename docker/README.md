# `docker/` — build helper’id

**Siin ei ela teenuste Dockerfile’id.** Need on `services/<nimi>/Dockerfile`.

`docker/` all on jagatud skriptid (`go-build.sh`, `gen-go-dockerfiles.sh`) ja
Makefile, millega `make docker` ehitab kõik image’id.

Kohalikuks sidumiseks: repo juure `docker-compose.yml`.
