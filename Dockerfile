# check=skip=UndefinedVar
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG ANDROID_NDK_VERSION=r27b

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${CUDA_HOME}/bin:/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
ENV ANDROID_NDK_HOME=/opt/android-ndk \
  NDK=/opt/android-ndk \
  MINGW_SUPPRESS_WARNINGS="-Wno-declaration-after-statement -Wno-array-parameter -Wno-deprecated-declarations -Wno-format -Wno-unused-but-set-variable -Wno-unknown-pragmas -Wno-uninitialized -Wno-undef -Wno-dangling-pointer -Wno-stringop-overflow -Wno-array-bounds -Wno-alloc-size-larger-than -Wno-unused-function -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast"

RUN apt-get update && apt-get install -y \
  build-essential git curl wget ca-certificates pkg-config yasm nasm unzip \
  autoconf automake libtool libtool-bin cmake ninja-build \
  python3 python3-pip zstd \
  libva-dev libdrm-dev gnupg clang llvm \
  mingw-w64 g++-mingw-w64 gcc-mingw-w64 \
  && rm -rf /var/lib/apt/lists/*

# Instala el toolkit de CUDA para habilitar nvcc (soporte NVENC/CUDA en builds).
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb \
  && dpkg -i /tmp/cuda-keyring.deb \
  && rm /tmp/cuda-keyring.deb \
  && apt-get update \
  && apt-get install -y cuda-toolkit-12-6 \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /build/sources /build/dist /output

RUN curl -L "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip" -o /tmp/android-ndk.zip \
  && unzip -q /tmp/android-ndk.zip -d /opt \
  && mv /opt/android-ndk-* /opt/android-ndk \
  && rm /tmp/android-ndk.zip

WORKDIR /build
COPY config.sh /build/config.sh
COPY scripts /build/scripts

RUN chmod +x /build/scripts/*.sh /build/scripts/platforms/*.sh /build/scripts/deps/windows/*.sh

VOLUME ["/output", "/build/sources"]

ENTRYPOINT ["/build/scripts/main.sh"]