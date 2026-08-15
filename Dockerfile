FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    SSH_USER=ubuntu \
    SSH_PORT=22 \
    PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWzSUJP9M/CdbyFJrvmcrVe83+4givFPry52NXl8Jxb Hrv Clan"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    curl \
    wget \
    nano \
    vim \
    net-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

COPY entrypoint.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/init.sh"]
