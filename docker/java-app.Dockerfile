# Shared build recipe for IVXV offline Java applications (key, processor, auditor).
# Prefer the per-app Dockerfiles under key/, processor/, and auditor/.
#
# Build example:
#   docker build -f key/Dockerfile -t ivxv/key .

# syntax=docker/dockerfile:1

ARG APP=key
ARG MAIN_CLASS=

FROM eclipse-temurin:21-jdk-jammy AS builder

ARG APP
ENV GRADLE_USER_HOME=/src/common/external/java \
	GRADLE_VERSION=8.11

WORKDIR /src

RUN apt-get update \
	&& apt-get install -y --no-install-recommends curl unzip ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /src/common/external \
	&& curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
	&& unzip -q /tmp/gradle.zip -d /src/common/external \
	&& rm /tmp/gradle.zip

COPY common/java ./common/java
COPY ${APP} ./${APP}

WORKDIR /src/${APP}
# Online dependency resolution inside the container.
RUN ../common/external/gradle-${GRADLE_VERSION}/bin/gradle \
	--no-daemon \
	build installDist \
	-x test

FROM eclipse-temurin:21-jre-jammy AS runtime

ARG APP

RUN useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv \
	&& mkdir -p /opt/ivxv /etc/ivxv

COPY --from=builder /src/${APP}/build/install/${APP} /opt/ivxv/${APP}

RUN chown -R ivxv:ivxv /opt/ivxv /etc/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv

ENV PATH="/opt/ivxv/${APP}/bin:${PATH}"

# Default to the application launcher; override for subcommands as needed.
ENTRYPOINT ["/bin/bash", "-c", "exec \"/opt/ivxv/${APP}/bin/${APP}\" \"$@\"", "--"]
