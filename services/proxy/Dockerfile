# IVXV Proxy (HAProxy SNI dispatcher) microservice
#
# Service lives in services/proxy/; Dockerfile is co-located with the service.
# Build from the repository root (required for shared modules):
#   docker build -f services/proxy/Dockerfile -t ivxv/proxy .
#
# Runtime configuration containers are expected under /etc/ivxv.
# The proxy manages a local HAProxy instance, so the container runs as root.

# syntax=docker/dockerfile:1

FROM golang:1.23-bookworm AS builder

WORKDIR /src

COPY docker/go-build.sh /usr/local/bin/ivxv-go-build
RUN chmod +x /usr/local/bin/ivxv-go-build

COPY core ./core
COPY common/collector ./common/collector
COPY common/tools/go ./common/tools/go
COPY scripts/goimports.sh ./scripts/goimports.sh
COPY services/proxy ./services/proxy

RUN ivxv-go-build proxy

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates haproxy \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /etc/ivxv /etc/haproxy /var/log/ivxv /usr/share/ivxv /run/haproxy

COPY --from=builder /out/ /usr/bin/
COPY services/proxy/service/proxy/haproxy.cfg.tmpl services/proxy/service/proxy/haproxy-rsyslog.conf /usr/share/ivxv/

EXPOSE 443
ENTRYPOINT ["proxy"]
