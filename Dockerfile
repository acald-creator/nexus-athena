# =============================================================================
# nexus-athena: Multi-stage, multi-platform Docker image
# Build with: docker buildx build --platform linux/amd64,linux/arm64 .
#
# Stages:
#   rust-builder   - Compile Rust offensive tool crates
#   python-builder - Install Python orchestrator + dependencies
#   athena-core    - Lightweight recon/scripting + OPAR agent runtime
#   athena-full    - Full offensive toolkit (Metasploit, Wireshark, radare2)
#
# Runtime Profiles (documented via OCI labels):
#   standard     - No additional capabilities required
#   packet-lab   - Requires: NET_ADMIN, NET_RAW
#   exploit-lab  - Requires: NET_ADMIN, NET_RAW, SYS_PTRACE
#   agent        - LLM-driven OPAR loop (network to inference endpoint)
#   agent-ics    - OPAR + ICS_WRITE, CAN_INJECT capabilities
# =============================================================================

# -----------------------------------------------------------------------------
# Stage: rust-builder
# Compile Rust crates from athena-agents for offensive tool binaries.
# -----------------------------------------------------------------------------
FROM rust:1.77-slim-bookworm AS rust-builder
ARG TARGETPLATFORM

WORKDIR /build

# Copy workspace definition and crates
COPY athena-agents/Cargo.toml athena-agents/Cargo.lock ./
COPY athena-agents/crates/ ./crates/

# Build all workspace members in release mode
RUN cargo build --release --workspace 2>/dev/null || true
# Collect binaries (some may not exist if crates are lib-only)
RUN mkdir -p /out && \
    for bin in athena-modbus athena-canbus athena-scanner athena-fuzzer athena-crafter; do \
        if [ -f "target/release/$bin" ]; then cp "target/release/$bin" /out/; fi; \
    done && \
    ls -la /out/

# -----------------------------------------------------------------------------
# Stage: python-builder
# Install Python orchestrator package with pinned dependencies.
# -----------------------------------------------------------------------------
FROM python:3.11-slim-bookworm AS python-builder

WORKDIR /build

# Copy orchestrator source
COPY athena-agents/pyproject.toml ./
COPY athena-agents/orchestrator/ ./orchestrator/
COPY athena-agents/eval/ ./eval/

# Install to a clean prefix for easy COPY
RUN pip install --no-cache-dir --prefix=/install . && \
    find /install -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stage: athena-core
# Lightweight recon + scripting tools + OPAR agent runtime.
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
LABEL org.opencontainers.image.description="Lightweight Kali-based recon and scripting image with OPAR agent runtime for the Athena subsystem."
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL org.opencontainers.image.source="https://github.com/phoenixvlabs/nexus-athena"
LABEL org.opencontainers.image.base.name="kalilinux/kali-rolling"
LABEL io.nexus.athena.target="athena-core"
LABEL io.nexus.athena.profile.standard="No additional capabilities required"
LABEL io.nexus.athena.profile.packet-lab="Requires: NET_ADMIN, NET_RAW"
LABEL io.nexus.athena.profile.exploit-lab="Requires: NET_ADMIN, NET_RAW, SYS_PTRACE"
LABEL io.nexus.athena.profile.agent="LLM-driven OPAR loop"
LABEL io.nexus.athena.profile.agent-ics="OPAR + ICS_WRITE, CAN_INJECT"
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

# Copy Rust tool binaries from builder
COPY --from=rust-builder /out/ /usr/local/bin/

# Copy Python orchestrator from builder
COPY --from=python-builder /install/lib/ /usr/local/lib/
COPY --from=python-builder /install/bin/ /usr/local/bin/

# Copy entrypoint script
COPY scripts/athena-agent-entrypoint.sh /usr/local/bin/athena-agent-entrypoint.sh
RUN chmod +x /usr/local/bin/athena-agent-entrypoint.sh

# Set agent runtime environment
ENV ATHENA_BIN_DIR=/usr/local/bin
ENV ATHENA_CONFIG_DIR=/opt/athena/config
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages

# Create non-root user as default execution identity
RUN groupadd -g 1000 athena && \
    useradd -m -u 1000 -g 1000 -s /bin/bash athena

# Create config and output mount points
RUN mkdir -p /opt/athena/config /opt/athena/output && \
    chown -R athena:athena /opt/athena

WORKDIR /home/athena
USER athena

# -----------------------------------------------------------------------------
# Stage: athena-full
# Extends athena-core with Metasploit Framework, Wireshark (tshark), and radare2.
# -----------------------------------------------------------------------------
FROM athena-core AS athena-full

ARG TARGETPLATFORM
ARG RADARE2_REF=5.9.8

LABEL org.opencontainers.image.title="nexus-athena-full"
LABEL org.opencontainers.image.description="Full Kali-based offensive toolkit for the Athena subsystem. Extends athena-core with Metasploit Framework, Wireshark, and radare2."
LABEL io.nexus.athena.target="athena-full"
LABEL io.nexus.athena.radare2.ref="${RADARE2_REF}"

USER root

RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        metasploit-framework \
        wireshark \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

USER athena
WORKDIR /home/athena
