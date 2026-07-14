# check=skip=UndefinedVar
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG ANDROID_NDK_VERSION=r27d

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${CUDA_HOME}/bin:/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
ENV ANDROID_NDK_HOME=/opt/android-ndk \
  NDK=/opt/android-ndk

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

# Instala el toolkit de CUDA
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb \
  && dpkg -i /tmp/cuda-keyring.deb \
  && rm /tmp/cuda-keyring.deb \
  && apt-get update \
  && apt-get install -y cuda-toolkit-12-6 \
  && rm -rf /var/lib/apt/lists/*

# Copia los tarballs descargados en el host
COPY temp/docker-build/downloads /downloads

# Extrae NDK
RUN unzip -q /downloads/android-ndk-${ANDROID_NDK_VERSION}-linux.zip -d /opt \
  && mv /opt/android-ndk-* /opt/android-ndk

# Create logs dir
RUN mkdir -p /logs

# Copia los scripts constructores y precompila todas las librerías
COPY docker-builder /docker-builder
RUN chmod +x /docker-builder/*.sh

# Run patches and build, redirecting to log files
RUN /docker-builder/extract_deps.sh
RUN /docker-builder/patch_deps.sh > /logs/patch_libs.log 2>&1 || (cat /logs/patch_libs.log && exit 1)
RUN /docker-builder/build_libs.sh > /logs/build_libs.log 2>&1 || (tail -n 100 /logs/build_libs.log && exit 1)

# Copia script principal para build runtime
COPY config.sh /config.sh
COPY compile.sh /compile.sh
RUN chmod +x /compile.sh

VOLUME ["/dist"]

ENTRYPOINT ["/compile.sh"]
