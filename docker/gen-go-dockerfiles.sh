#!/bin/bash
# Regenerates Go microservice Dockerfiles under services/<name>/.
# Run from repository root: bash docker/gen-go-dockerfiles.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# name|entrypoint|needs_sessionstatus_api|extra_runtime_packages|description
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
	local name="$1" entry="$2" need_api="$3" pkgs="$4" desc="$5"
	local dir="services/${name}"
	local outfile="${ROOT}/${dir}/Dockerfile"
	local api_copy=""
	local runtime_pkgs="ca-certificates"
	local user_block=""
	local extra_copy=""
	local expose=""

	if [[ -n "${pkgs}" ]]; then
		runtime_pkgs="${runtime_pkgs} ${pkgs}"
	fi
	if [[ "${need_api}" == "1" ]]; then
		api_copy='COPY services/sessionstatus/api ./services/sessionstatus/api'
	fi

	if [[ "${name}" == "proxy" ]]; then
		extra_copy='COPY services/proxy/service/proxy/haproxy.cfg.tmpl services/proxy/service/proxy/haproxy-rsyslog.conf /usr/share/ivxv/'
		expose='EXPOSE 443'
		user_block=$(cat <<'USERBLOCK'
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates haproxy \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /etc/ivxv /etc/haproxy /var/log/ivxv /usr/share/ivxv /run/haproxy

COPY --from=builder /out/ /usr/bin/
COPY services/proxy/service/proxy/haproxy.cfg.tmpl services/proxy/service/proxy/haproxy-rsyslog.conf /usr/share/ivxv/

EXPOSE 443
ENTRYPOINT ["proxy"]
USERBLOCK
)
	else
		user_block=$(cat <<USERBLOCK
RUN apt-get update \\
	&& apt-get install -y --no-install-recommends ${runtime_pkgs} \\
	&& rm -rf /var/lib/apt/lists/* \\
	&& useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv

COPY --from=builder /out/ /usr/bin/

RUN mkdir -p /etc/ivxv /var/log/ivxv /usr/share/ivxv \\
	&& chown -R ivxv:ivxv /etc/ivxv /var/log/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv

ENTRYPOINT ["${entry}"]
USERBLOCK
)
	fi

	if [[ "${name}" == "proxy" ]]; then
		cat > "${outfile}" <<EOF
# IVXV ${desc}
#
# Service lives in ${dir}/; Dockerfile is co-located with the service.
# Build from the repository root (required for shared modules):
#   docker build -f ${dir}/Dockerfile -t ivxv/${name} .
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
COPY ${dir} ./${dir}

RUN ivxv-go-build ${name}

FROM debian:bookworm-slim AS runtime

${user_block}
EOF
	else
		# For sessionstatus, copy the whole service tree (includes api).
		local service_copy="COPY ${dir} ./${dir}"
		if [[ "${name}" == "sessionstatus" ]]; then
			api_copy=""
		fi

		cat > "${outfile}" <<EOF
# IVXV ${desc}
#
# Service lives in ${dir}/; Dockerfile is co-located with the service.
# Build from the repository root (required for shared modules):
#   docker build -f ${dir}/Dockerfile -t ivxv/${name} .
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
${service_copy}

RUN ivxv-go-build ${name}

FROM debian:bookworm-slim AS runtime

${user_block}
EOF
	fi

	# Drop accidental empty lines created by optional COPY blocks.
	sed -i '/^$/N;/^\n$/D' "${outfile}"
	echo "wrote ${outfile}"
}

for spec in "${SERVICES[@]}"; do
	IFS='|' read -r name entry need_api pkgs desc <<<"${spec}"
	write_dockerfile "${name}" "${entry}" "${need_api}" "${pkgs}" "${desc}"
done
