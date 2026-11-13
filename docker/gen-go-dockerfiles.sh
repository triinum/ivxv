#!/bin/bash
# Regenerates Go microservice Dockerfiles from the service catalog below.
# Run from repository root: bash docker/gen-go-dockerfiles.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# service_dir|entrypoint|needs_sessionstatus_api|extra_runtime_packages|description
SERVICES=(
	'proxy|proxy|0|haproxy|Proxy (HAProxy SNI dispatcher) microservice'
	'choices|choices|1||Choices (voter lists) microservice'
	'voting|voting|1||Voting microservice'
	'verification|verification|1||Verification microservice'
	'storage|storage|0||Storage microservice'
	'mid|mid|1||Mobile-ID helper microservice'
	'smartid|smartid|1||Smart-ID helper microservice'
	'webeid|webeid|1||Web eID helper microservice'
	'sessionstatus|sessionstatus|1||Session status microservice'
	'votesorder|votesorder|0||Votes order microservice'
)

write_dockerfile() {
	local dir="$1" entry="$2" need_api="$3" pkgs="$4" desc="$5"
	local outfile="${ROOT}/${dir}/Dockerfile"
	local api_copy=""
	local runtime_pkgs="ca-certificates"
	if [[ -n "${pkgs}" ]]; then
		runtime_pkgs="${runtime_pkgs} ${pkgs}"
	fi
	if [[ "${need_api}" == "1" ]]; then
		api_copy='COPY sessionstatus/api ./sessionstatus/api'
	fi

	local extra_copy=""
	if [[ "${dir}" == "proxy" ]]; then
		extra_copy='COPY proxy/service/proxy/haproxy.cfg.tmpl proxy/service/proxy/haproxy-rsyslog.conf /usr/share/ivxv/'
	fi

	cat > "${outfile}" <<EOF
# IVXV ${desc}
#
# Developed and released independently of other microservices.
# Build from the repository root (required for shared modules):
#   docker build -f ${dir}/Dockerfile -t ivxv/${dir} .
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
${api_copy}
COPY ${dir} ./${dir}

RUN ivxv-go-build ${dir}

FROM debian:bookworm-slim AS runtime

RUN apt-get update \\
	&& apt-get install -y --no-install-recommends ${runtime_pkgs} \\
	&& rm -rf /var/lib/apt/lists/* \\
	&& useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv

COPY --from=builder /out/ /usr/bin/
${extra_copy}

RUN mkdir -p /etc/ivxv /var/log/ivxv /usr/share/ivxv \\
	&& chown -R ivxv:ivxv /etc/ivxv /var/log/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv

ENTRYPOINT ["${entry}"]
EOF

	# Clean up accidental blank lines from optional COPY blocks.
	sed -i '/^$/N;/^\n$/D' "${outfile}"
	echo "wrote ${outfile}"
}

for spec in "${SERVICES[@]}"; do
	IFS='|' read -r dir entry need_api pkgs desc <<<"${spec}"
	write_dockerfile "${dir}" "${entry}" "${need_api}" "${pkgs}" "${desc}"
done
