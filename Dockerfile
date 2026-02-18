FROM ubuntu:24.04

ARG USER_NAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# Install build toolchains and dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make cmake \
    golang-go \
    nodejs npm \
    git curl wget ca-certificates jq ripgrep \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create user matching host UID/GID (handle pre-existing UID/GID in base image)
RUN userdel -f $(id -un ${USER_UID} 2>/dev/null) 2>/dev/null || true \
    && groupadd -f --gid ${USER_GID} ${USER_NAME} 2>/dev/null || true \
    && useradd --non-unique --uid ${USER_UID} --gid ${USER_GID} -m ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set GOPATH
ENV GOPATH=/home/${USER_NAME}/go
ENV PATH="${GOPATH}/bin:${PATH}"

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
