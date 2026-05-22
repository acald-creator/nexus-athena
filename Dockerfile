FROM kalilinux/kali-bleeding-edge:amd64

ARG TERRAFORM_VERSION=1.2.7
ARG RADARE2_REF=5.9.8
ARG VERSION
ENV VERSION $VERSION
ARG BUILD_TIMESTAMP
ENV BUILD_TIMESTAMP $BUILD_TIMESTAMP

LABEL description="Custom Kali Linux Bleeding Edge repository Docker image configured with pre-installed packages such as Nmap, Wireshark, Metasploit Framework, and radare2."
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.created=$BUILD_TIMESTAMP
LABEL org.opencontainers.image.source="https://github.com/fenixsecurelabs/nexus-athena"

VOLUME ["/var/run", "/var/lib/docker/volumes", "/nexus-bucket"]

RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        gcc \
        g++ \
        build-essential \
        ca-certificates \
        wget \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* 2> /dev/null

RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        vim \
        nmap \
        wireshark \
        git \
        unzip \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* 2> /dev/null

RUN apt-get update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq \
        metasploit-framework \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* 2> /dev/null

RUN git clone --branch "${RADARE2_REF}" --depth 1 https://github.com/radareorg/radare2 && \
    sh radare2/sys/install.sh

RUN rm -rf radare2 2> /dev/null

RUN wget -O terraform-amd64.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform-amd64.zip && \
    mv terraform /usr/local/bin && \
    touch ~/.bashrc && \
    terraform -install-autocomplete

RUN rm terraform-amd64.zip 2> /dev/null
