FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git tmux \
    default-mysql-client iputils-ping dnsutils net-tools \
    nmap netcat-openbsd sshpass rsyslog ca-certificates \
    sqlmap hydra john gobuster tcpdump \
    python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/attacks
COPY attacks/ /opt/attacks/
RUN chmod +x /opt/attacks/*.sh
WORKDIR /opt/attacks

CMD ["sleep", "infinity"]