FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl nmap python3 python3-pip wget dnsutils netcat-openbsd sshpass rsyslog ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir sqlmap
RUN mkdir -p /opt/attacks
COPY attacks/ /opt/attacks/
RUN chmod +x /opt/attacks/*.sh
WORKDIR /opt/attacks
CMD ["sleep", "infinity"]
