FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates iproute2 iputils-ping curl jq \
    && rm -rf /var/lib/apt/lists/*
# create SSH dir
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
# ensure sshd config
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true
RUN mkdir -p /var/run/sshd
EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]
