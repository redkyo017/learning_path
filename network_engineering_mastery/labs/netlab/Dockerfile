# netlab — one privileged box; every lab topology is built from bare network
# namespaces inside it. See labs/netlab/README.md.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
# No init system here: stop package postinst scripts from trying to start services.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d
RUN apt-get update && apt-get install -y --no-install-recommends \
      iproute2 iputils-ping iputils-tracepath traceroute ethtool kmod procps less \
      tcpdump tshark nftables conntrack iperf3 netcat-openbsd curl dnsutils \
      frr unbound python3 neovim ca-certificates \
      dnsmasq-base dhcpcd-base \
    && rm -rf /var/lib/apt/lists/*
# Marker that common.sh's require_netlab checks for.
RUN touch /.netlab && mkdir -p /run/netlab
WORKDIR /course
CMD ["sleep", "infinity"]
