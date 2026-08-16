# =============================================================================
# nexus-athena: Multi-stage, multi-platform Docker image
# Replaces both Dockerfile and Dockerfile.arm64 with a single build definition.
# Build with: docker buildx build --platform linux/amd64,linux/arm64 .
#
# Targets:
#   athena-core  - Lightweight recon and scripting tools
#   athena-full  - Full offensive toolkit (Metasploit, Wireshark, radare2)
#
# Runtime Profiles (documented via OCI labels):
#   standard     - No additional capabilities required
#   packet-lab   - Requires: NET_ADMIN, NET_RAW
#   exploit-lab  - Requires: NET_ADMIN, NET_RAW, SYS_PTRACE
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: athena-core
# Recon + scripting tools. No Metasploit, Wireshark, or radare2.
# Target compressed size: <= 1.5 GB
# -----------------------------------------------------------------------------
FROM kalilinux/kali-rolling AS athena-core

ARG TARGETPLATFORM
ARG VERSION
ARG BUILD_TIMESTAMP

ENV VERSION=${VERSION}
ENV BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

# OCI labels
LABEL org.opencontainers.image.title="nexus-athena-core"
LABEL org.opencontainers.image.description="Lightweight Kali-based recon and scripting image for the Athena subsystem. Includes Nmap, Python 3, Scapy, and networking utilities."
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL org.opencontainers.image.source="https://github.com/phoenixvlabs/nexus-athena"
LABEL org.opencontainers.image.base.name="kalilinux/kali-rolling"
# Capability documentation
LABEL io.nexus.athena.target="athena-core"
LABEL io.nexus.athena.profile.standard="No additional capabilities required"
LABEL io.nexus.athena.profile.packet-lab="Requires: NET_ADMIN, NET_RAW"
LABEL io.nexus.athena.profile.exploit-lab="Requires: NET_ADMIN, NET_RAW, SYS_PTRACE"
LABEL io.nexus.athena.default-user="athena (UID 1000)"

# Install core recon and scripting packages in a single layer
RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        ca-certificates \
        curl \
        dnsutils \
        git \
        iproute2 \
        netcat-openbsd \
        nmap \
        python3 \
        python3-pip \
        python3-scapy \
        tcpdump \
        vim \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user as default execution identity
RUN groupadd -g 1000 athena && \
    useradd -m -u 1000 -g 1000 -s /bin/bash athena

WORKDIR /home/athena
USER athena

# -----------------------------------------------------------------------------
# Stage 2: athena-full
# Extends athena-core with Metasploit Framework, Wireshark (tshark), and radare2.
# -----------------------------------------------------------------------------
FROM athena-core AS athena-full

ARG TARGETPLATFORM
ARG RADARE2_REF=5.9.8

# Update labels for full target
LABEL org.opencontainers.image.title="nexus-athena-full"
LABEL org.opencontainers.image.description="Full Kali-based offensive toolkit for the Athena subsystem. Extends athena-core with Metasploit Framework, Wireshark, and radare2."
LABEL io.nexus.athena.target="athena-full"
LABEL io.nexus.athena.radare2.ref="${RADARE2_REF}"

# Switch to root for package installation
USER root

# Install Metasploit and Wireshark (tshark CLI)
RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        metasploit-framework \
        wireshark \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install build dependencies for radare2, build it, then remove build deps
RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        build-essential \
        gcc \
        g++ \
        make \
        pkg-config \
    && git clone --branch "${RADARE2_REF}" --depth 1 https://github.com/radareorg/radare2 /tmp/radare2 \
    && cd /tmp/radare2 && sh sys/install.sh \
    && rm -rf /tmp/radare2 \
    && apt-get purge -y --auto-remove build-essential gcc g++ make pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to non-root user
USER athena
WORKDIR /home/athena
