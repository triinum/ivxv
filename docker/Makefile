# Build IVXV microservice container images.
# Usage (from repo root): make -C docker all
# Or: make docker

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

GO_SERVICES := \
	proxy \
	choices \
	voting \
	verification \
	storage \
	mid \
	smartid \
	webeid \
	sessionstatus \
	votesorder

OTHER_SERVICES := \
	xroad-service \
	collector-admin

OFFLINE_APPS := \
	key \
	processor \
	auditor

ALL_IMAGES := $(GO_SERVICES) $(OTHER_SERVICES) $(OFFLINE_APPS)

.PHONY: all help $(ALL_IMAGES) online offline

help:
	@echo "usage: make -C docker all       Build all service images"
	@echo "       make -C docker online    Build online collector microservices"
	@echo "       make -C docker offline   Build offline Java applications"
	@echo "       make -C docker <name>    Build one image (e.g. voting)"

all: $(ALL_IMAGES)

online: $(GO_SERVICES) $(OTHER_SERVICES)

offline: $(OFFLINE_APPS)

$(ALL_IMAGES):
	docker build -f $(ROOT)/$@/Dockerfile -t ivxv/$@ $(ROOT)
