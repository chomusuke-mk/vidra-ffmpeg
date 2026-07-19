# check=skip=UndefinedVar
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# 1. Instalar dependencias
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential git curl wget ca-certificates pkg-config yasm nasm unzip \
  autoconf automake libtool libtool-bin libltdl-dev cmake ninja-build \
  python3 python3-pip zstd gperf autopoint \
  libva-dev libdrm-dev libkrb5-dev gnupg clang llvm texinfo gettext \
  mingw-w64 g++-mingw-w64 gcc-mingw-w64 \
  libfontconfig1-dev libfreetype6-dev libfribidi-dev libharfbuzz-dev libass-dev \
  libdav1d-dev libmp3lame-dev libopenjp2-7-dev libsnappy-dev libsoxr-dev libssh-dev \
  libsvtav1-dev libvpl-dev libvpx-dev libwebp-dev libx265-dev libxml2-dev libopus-dev \
  libvulkan-dev zlib1g-dev libzimg-dev libssl-dev \
  libsvtav1enc-dev libsvtav1dec-dev libx264-dev libnuma-dev liblzma-dev \
  libxcb1-dev libx11-dev libx11-xcb-dev libxext-dev libwayland-dev wayland-protocols libxrandr-dev \
  xutils-dev x11proto-dev xcb-proto python3-xcbgen \
  libxcursor-dev libxinerama-dev libxi-dev libxss-dev libxfixes-dev libxrender-dev libxkbcommon-dev libxtst-dev \
  libxv-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "$HOME/.cargo/env" && \
    cargo install cargo-c
ENV PATH="/root/.cargo/bin:${PATH}"

RUN pip3 install --break-system-packages meson glad2

# Instalar Android NDK
RUN wget https://dl.google.com/android/repository/android-ndk-r27d-linux.zip -O /tmp/android-ndk-linux.zip \
    && mkdir -p /tmp/android-ndk-linux /opt/android-ndk-linux \
    && unzip /tmp/android-ndk-linux.zip -d /tmp/android-ndk-linux \
    && mv /tmp/android-ndk-linux/*/* /opt/android-ndk-linux \
    && rm -rf /tmp/android-ndk-linux.zip /tmp/android-ndk-linux
ENV ANDROID_NDK_HOME=/opt/android-ndk-linux

# Instalar CUDA Toolkit
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb \
  && dpkg -i /tmp/cuda-keyring.deb \
  && rm /tmp/cuda-keyring.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends cuda-toolkit-12-6 \
  && rm -rf /var/lib/apt/lists/*
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${CUDA_HOME}/bin:$PATH

# copiar herramientas de construcción de la imagen
COPY docker-builder /docker-builder
RUN chmod +x /docker-builder/*.sh

# 3. MEGA-CAPA: Descargar, parchear, compilar y DESTRUIR rastros
WORKDIR /vidra
ARG TARGET_OS=all
ARG TARGET_ARCH=all
RUN --mount=type=cache,target=/downloads \
    mkdir -p /downloads /source /compiled /vidra-tmp /vidra && \
    /docker-builder/download_deps.sh /downloads && \
    /docker-builder/extract_deps.sh /downloads /source && \
    /docker-builder/patch_deps.sh /docker-builder/patches /source && \
    /docker-builder/build_libs.sh /source /compiled /vidra-tmp ${TARGET_OS} ${TARGET_ARCH} && \
    rm -rf /source /docker-builder /vidra-tmp /vidra && \
    mkdir -p /vidra

ENV COMPILATION_DIR=/compiled
