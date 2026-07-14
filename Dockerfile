# check=skip=UndefinedVar
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# 1. Instalar dependencias
RUN apt-get update && apt-get install -y \
  build-essential git curl wget ca-certificates pkg-config yasm nasm unzip \
  autoconf automake libtool libtool-bin cmake ninja-build meson \
  python3 python3-pip zstd gperf \
  libva-dev libdrm-dev libkrb5-dev gnupg clang llvm \
  mingw-w64 g++-mingw-w64 gcc-mingw-w64 \
  libfontconfig1-dev libfreetype6-dev libfribidi-dev libharfbuzz-dev libass-dev \
  libdav1d-dev libmp3lame-dev libopenjp2-7-dev libsnappy-dev libsoxr-dev libssh-dev \
  libsvtav1-dev libvpl-dev libvpx-dev libwebp-dev libx265-dev libxml2-dev libopus-dev \
  libvulkan-dev zlib1g-dev libzimg-dev libssl-dev ocl-icd-opencl-dev \
  && rm -rf /var/lib/apt/lists/*

# Instalar Android NDK
ARG NDK_VERSION=r27d
WORKDIR /opt
RUN wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip \
    && unzip -q android-ndk-${NDK_VERSION}-linux.zip \
    && mv android-ndk-${NDK_VERSION} android-ndk-linux \
    && rm android-ndk-${NDK_VERSION}-linux.zip
ENV ANDROID_NDK_HOME=/opt/android-ndk-linux
ENV NDK_HOME=/opt/android-ndk-linux

# Instalar CUDA Toolkit
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb \
  && dpkg -i /tmp/cuda-keyring.deb \
  && rm /tmp/cuda-keyring.deb \
  && apt-get update \
  && apt-get install -y cuda-toolkit-12-6 \
  && rm -rf /var/lib/apt/lists/*
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${CUDA_HOME}/bin:/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# copiar herramientas de construcción de la imagen
COPY docker-builder /docker-builder
RUN chmod +x /docker-builder/*.sh

# 3. MEGA-CAPA: Descargar, parchear, compilar y DESTRUIR rastros
RUN --mount=type=cache,target=/downloads \
    mkdir -p /downloads /source /compiled && \
    /docker-builder/download_deps.sh /downloads && \
    /docker-builder/extract_deps.sh /downloads /source && \
    /docker-builder/patch_deps.sh /docker-builder/patches /source && \
    /docker-builder/build_libs.sh /source /compiled && \
    rm -rf /source /docker-builder /var/lib/apt/lists/*

ENV COMPILATION_DIR=/compiled