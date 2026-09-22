FROM nvidia/cuda:13.4.1-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang \
        clangd \
        cmake \
        curl \
        gdb \
        git \
        jq \
        less \
        libfreetype6 \
        libxi6 \
        libxext6 \
        libxrender1 \
        libxtst6 \
        ninja-build \
        openssh-client \
        pkg-config \
        procps \
        python3 \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh

ENV CUDA_HOME=/usr/local/cuda
ENV CUDACXX=/usr/local/cuda/bin/nvcc
ENV PATH=/usr/local/cuda/bin:/usr/local/bin:${PATH}

WORKDIR /workspace
