# IVXV Collector administration microservice
#
# Developed and released independently of other microservices.
# Build from the repository root:
#   docker build -f collector-admin/Dockerfile -t ivxv/collector-admin .
#
# Exposes the management HTTP daemon (default port 8080). Full production
# deployments also use Apache/WSGI; this image focuses on the admin daemon
# for independent service development and testing.

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

# Install the admin package and its Python dependencies from the monorepo.
COPY setup.py setup.cfg ./
COPY collector-admin ./collector-admin
COPY Documentation/common/schema ./Documentation/common/schema

RUN pip install --no-cache-dir . \
	&& mkdir -p /etc/ivxv \
	&& cp collector-admin/ivxv-collector-admin.conf /etc/ivxv/ \
	&& cp -a collector-admin/site/. /var/www/collector-admin/ \
	&& chown -R ivxv:ivxv /etc/ivxv /var/log/ivxv /var/lib/ivxv /var/www/collector-admin \
	&& rm -rf /src

USER ivxv
WORKDIR /var/lib/ivxv

EXPOSE 8080
ENTRYPOINT ["ivxv-admin-httpd"]
