# IVXV X-Road bridge microservice
#
# Service lives in services/xroad-service/; Dockerfile is co-located with the service.
# Build from the repository root:
#   docker build -f services/xroad-service/Dockerfile -t ivxv/xroad-service .
#
# Configuration defaults to /etc/xroad-service/xroad-service.json.

# syntax=docker/dockerfile:1

FROM golang:1.23-bookworm AS builder

WORKDIR /src/services/xroad-service

COPY services/xroad-service/go.mod services/xroad-service/go.sum ./
RUN go mod download

COPY services/xroad-service/ ./

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/xroad-service ./cmd

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --system --uid 10001 --home-dir /var/lib/xroad-service --create-home xroad \
	&& mkdir -p /etc/xroad-service

COPY --from=builder /out/xroad-service /usr/bin/xroad-service
COPY services/xroad-service/pkg/configs/xroad-service.json /etc/xroad-service/xroad-service.json
COPY services/xroad-service/openapi/ehs-xroad-api.yaml /etc/xroad-service/ehs-xroad-api.yaml

RUN chown -R xroad:xroad /etc/xroad-service /var/lib/xroad-service

USER xroad
WORKDIR /var/lib/xroad-service

EXPOSE 8080
ENTRYPOINT ["xroad-service"]
