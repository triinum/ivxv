# IVXV Collector administration microservice
#
# Service lives in services/collector-admin/; Dockerfile is co-located with the service.
# Build from the repository root:
#   docker build -f services/collector-admin/Dockerfile -t ivxv/collector-admin .
#
# Exposes the management HTTP daemon (default port 8080).

# syntax=docker/dockerfile:1

FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1 \
	IVXV_ADMIN_CONF=/etc/ivxv/ivxv-collector-admin.conf

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		openssl \
		rsync \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv \
	&& mkdir -p /etc/ivxv /var/log/ivxv /var/www/collector-admin

WORKDIR /src

COPY setup.py setup.cfg ./
COPY services/collector-admin ./services/collector-admin
COPY Documentation/common/schema ./Documentation/common/schema

RUN pip install --no-cache-dir . \
	&& mkdir -p /etc/ivxv \
	&& cp services/collector-admin/ivxv-collector-admin.conf /etc/ivxv/ \
	&& cp -a services/collector-admin/site/. /var/www/collector-admin/ \
	&& chown -R ivxv:ivxv /etc/ivxv /var/log/ivxv /var/lib/ivxv /var/www/collector-admin \
	&& rm -rf /src

USER ivxv
WORKDIR /var/lib/ivxv

EXPOSE 8080
ENTRYPOINT ["ivxv-admin-httpd"]
