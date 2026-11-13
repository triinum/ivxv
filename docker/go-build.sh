#!/bin/bash
# Shared build helper for IVXV Go microservices under services/<name>/.
# Intended to run inside the builder stage with WORKDIR=/src (repo root).
#
# Usage: go-build.sh <service-name>
# Example: go-build.sh voting
set -euo pipefail

NAME="${1:?service name required}"
ROOT="/src"
SERVICE_DIR="services/${NAME}"

if [[ ! -d "${ROOT}/${SERVICE_DIR}" ]]; then
	echo "error: service directory not found: ${ROOT}/${SERVICE_DIR}" >&2
	exit 1
fi

export GOTOOLCHAIN=local
export CGO_ENABLED=0
export GOBIN=/out
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
			go mod tidy
		)
	fi
}

ensure_core_replace "${ROOT}/common/collector" "../../core"
ensure_core_replace "${ROOT}/${SERVICE_DIR}" "../../core"
if [[ -f "${ROOT}/services/sessionstatus/api/go.mod" ]]; then
	ensure_core_replace "${ROOT}/services/sessionstatus/api" "../../../core"
fi
if [[ "${NAME}" == "sessionstatus" ]]; then
	ensure_core_replace "${ROOT}/services/sessionstatus" "../../core"
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
	go generate ./...
	"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
)

if [[ -d "${ROOT}/services/sessionstatus/api" ]]; then
	echo "==> codegen: sessionstatus/api"
	(
		cd "${ROOT}/services/sessionstatus/api"
		go generate ./... || true
		"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
	)
fi

echo "==> build: ${SERVICE_DIR}"
(
	cd "${ROOT}/${SERVICE_DIR}"
	bash "${ROOT}/scripts/goimports.sh" ./...
	go generate ./...
	"${ROOT}/common/tools/go/bin/gen" -base "${ROOT}" ./...
	go install ./...
)

echo "Built ${NAME} binaries into ${GOBIN}:"
ls -la "${GOBIN}"
