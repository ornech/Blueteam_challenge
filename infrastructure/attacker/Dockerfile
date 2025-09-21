FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl default-mysql-client iputils-ping nmap python3 python3-pip wget dnsutils netcat-openbsd sshpass rsyslog ca-certificates sqlmap \
    && rm -rf /var/lib/apt/lists/*
# pip install sqlmap removed because Debian provides sqlmap package
RUN mkdir -p /opt/attacks
COPY attacks/ /opt/attacks/
RUN chmod +x /opt/attacks/*.sh
WORKDIR /opt/attacks
CMD ["sleep", "infinity"]
