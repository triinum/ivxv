# IVXV Auditor application (offline audit / proof verification tool)
#
# Developed independently of collector microservices.
# Build from the repository root:
#   docker build -f auditor/Dockerfile -t ivxv/auditor .

# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jdk-jammy AS builder

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
COPY auditor ./auditor

WORKDIR /src/auditor
RUN ../common/external/gradle-${GRADLE_VERSION}/bin/gradle \
	--no-daemon \
	build installDist \
	-x test

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv \
	&& mkdir -p /opt/ivxv /etc/ivxv

COPY --from=builder /src/auditor/build/install/auditor /opt/ivxv/auditor

RUN chown -R ivxv:ivxv /opt/ivxv /etc/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv
ENV PATH="/opt/ivxv/auditor/bin:${PATH}"

ENTRYPOINT ["auditor"]
