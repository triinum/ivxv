#!/bin/bash
# Shared build helper for IVXV Go microservices.
# Intended to run inside the builder stage with WORKDIR=/src (repo root).
#
# Usage: go-build.sh <service-dir>
set -euo pipefail

SERVICE="${1:?service directory required}"
ROOT="/src"

if [[ ! -d "${ROOT}/${SERVICE}" ]]; then
	echo "error: service directory not found: ${ROOT}/${SERVICE}" >&2
	exit 1
fi

export GOTOOLCHAIN=local
export CGO_ENABLED=0
export GOBIN=/out
# Scripts such as tlsciphersuites expect $GO (see common/go/govar.mk).
export GO="${GO:-go}"

mkdir -p "${GOBIN}"

# Use the in-repo crypto library instead of the private tivi.io module path.
ensure_core_replace() {
	local moddir="$1"
	local rel="$2"
	if [[ -f "${moddir}/go.mod" ]] && grep -q 'tivi.io/core' "${moddir}/go.mod"; then
		(
			cd "${moddir}"
			go mod edit -replace="tivi.io/core=${rel}"
			# Keep go.sum consistent with the local replace.
			go mod tidy
		)
	fi
}

ensure_core_replace "${ROOT}/common/collector" "../../core"
ensure_core_replace "${ROOT}/${SERVICE}" "../core"
if [[ -f "${ROOT}/sessionstatus/api/go.mod" ]]; then
	ensure_core_replace "${ROOT}/sessionstatus/api" "../../core"
fi
if [[ -f "${ROOT}/sessionstatus/go.mod" && "${SERVICE}" == "sessionstatus" ]]; then
	ensure_core_replace "${ROOT}/sessionstatus" "../core"
fi

# Ensure helper scripts copied from the build context are executable.
chmod +x "${ROOT}/scripts/goimports.sh" \
	"${ROOT}/core/cmd/errorgen/gentmpl.sh" \
	"${ROOT}/common/tools/go/cmd/gen/gentmpl.sh" \
	"${ROOT}/common/collector/server/tlsciphersuites" || true

echo "==> codegen: tivi.io/core"
(
	cd "${ROOT}/core/cmd/errorgen"
	go generate ./...
	GOBIN="${ROOT}/core/cmd/errorgen/bin" go install ./...
	cd "${ROOT}/core"
	"${ROOT}/core/cmd/errorgen/bin/errorgen" -base "${ROOT}/core" ./...
)

echo "==> codegen: common/tools/go + common/collector"
(
	cd "${ROOT}/common/tools/go"
	go generate ./...
	GOBIN="${ROOT}/common/tools/go/bin" go install ./...
)
(
	cd "${ROOT}/common/collector"
	# Collector packages also declare generated error types.
	go generate ./...
	"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
)

# sessionstatus/api may also need generated types when present.
if [[ -d "${ROOT}/sessionstatus/api" ]]; then
	echo "==> codegen: sessionstatus/api"
	(
		cd "${ROOT}/sessionstatus/api"
		go generate ./... || true
		"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
	)
fi

echo "==> build: ${SERVICE}"
(
	cd "${ROOT}/${SERVICE}"
	bash "${ROOT}/scripts/goimports.sh" ./...
	go generate ./...
	"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
	go install ./...
)

echo "Built ${SERVICE} binaries into ${GOBIN}:"
ls -la "${GOBIN}"
