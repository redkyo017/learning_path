FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections \
 && apt-get update && apt-get install -y --no-install-recommends \
    openssl curl tshark ca-certificates bash coreutils certbot \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
