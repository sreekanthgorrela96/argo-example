FROM jenkins/jenkins:lts-jdk17

USER root

# Docker CLI only (static binary) — talks to host engine via mounted socket; avoids pulling dockerd/containerd.
ARG DOCKER_VERSION=27.5.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64)  DARCH=x86_64 ;; \
         aarch64) DARCH=aarch64 ;; \
         *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://download.docker.com/linux/static/stable/${DARCH}/docker-${DOCKER_VERSION}.tgz" \
       | tar xz --strip-components=1 -C /usr/local/bin docker/docker \
    && docker --version

# Install plugins at build time (Pipeline, Git, credentials in pipelines)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
