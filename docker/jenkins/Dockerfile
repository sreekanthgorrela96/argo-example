FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install plugins at build time (Pipeline, Git, credentials in pipelines)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
