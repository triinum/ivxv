# IVXV Key application (offline key generation / decryption tool)
#
# Service lives in services/key/; Dockerfile is co-located with the service.
# Build from the repository root:
#   docker build -f services/key/Dockerfile -t ivxv/key .

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
COPY services/key ./services/key

WORKDIR /src/services/key
RUN ../../common/external/gradle-${GRADLE_VERSION}/bin/gradle \
	--no-daemon \
	build installDist \
	-x test

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN useradd --system --uid 10001 --home-dir /var/lib/ivxv --create-home ivxv \
	&& mkdir -p /opt/ivxv /etc/ivxv

COPY --from=builder /src/services/key/build/install/key /opt/ivxv/key

RUN chown -R ivxv:ivxv /opt/ivxv /etc/ivxv /var/lib/ivxv

USER ivxv
WORKDIR /var/lib/ivxv
ENV PATH="/opt/ivxv/key/bin:${PATH}"

ENTRYPOINT ["key"]
