FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    zip \
    git \
    vim \
    cron \
    htop \
    sudo \
    curl \
    tini \
    wget \
    ttyd \
    unzip \
    openssl \
    rsyslog \
    net-tools \
    supervisor \
    iputils-ping \
    ca-certificates \
    openssh-server \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

COPY entrypoint.sh /usr/bin/deamon
COPY supervisord.conf /etc/supervisor/conf.d/supervisor.conf
RUN chmod +x /usr/bin/deamon
RUN ln -s /usr/bin/tini /sbin/init

ENTRYPOINT ["/sbin/init", "--", "deamon"]
