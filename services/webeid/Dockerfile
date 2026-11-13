# IVXV Web eID helper microservice
#
# Service lives in services/webeid/; Dockerfile is co-located with the service.
# Build from the repository root (required for shared modules):
#   docker build -f services/webeid/Dockerfile -t ivxv/webeid .
#
# Runtime configuration containers are expected under /etc/ivxv.

# syntax=docker/dockerfile:1

FROM golang:1.23-bookworm AS builder

WORKDIR /src

COPY docker/go-build.sh /usr/local/bin/ivxv-go-build
RUN chmod +x /usr/local/bin/ivxv-go-build

# Shared libraries first for better layer caching when only the service changes.
COPY core ./core
COPY common/collector ./common/collector
COPY common/tools/go ./common/tools/go
COPY scripts/goimports.sh ./scripts/goimports.sh
COPY services/sessionstatus/api ./services/sessionstatus/api
COPY services/webeid ./services/webeid

RUN ivxv-go-build webeid

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv

COPY --from=builder /out/ /usr/bin/

RUN mkdir -p /etc/ivxv /var/log/ivxv /usr/share/ivxv \
	&& chown -R ivxv:ivxv /etc/ivxv /var/log/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv

ENTRYPOINT ["webeid"]
