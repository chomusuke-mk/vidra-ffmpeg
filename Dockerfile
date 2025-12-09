FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG ANDROID_NDK_VERSION=r27b

ENV ANDROID_NDK_HOME=/opt/android-ndk \
  NDK=/opt/android-ndk \
  PATH=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH \
  MINGW_SUPPRESS_WARNINGS="-Wno-dangling-pointer -Wno-stringop-overflow -Wno-array-bounds"

RUN apt-get update && apt-get install -y \
  build-essential git curl wget ca-certificates pkg-config yasm nasm unzip \
  autoconf automake libtool libtool-bin cmake ninja-build \
  python3 python3-pip zstd \
  libva-dev libdrm-dev \
  mingw-w64 g++-mingw-w64 gcc-mingw-w64 \
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