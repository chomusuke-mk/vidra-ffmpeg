#!/bin/bash
set -e

# --- Captura de Parámetros ---
TARGET_OS=${1:-"all"}
TARGET_ARCH=${2:-"all"}

# shellcheck disable=SC1091
source /config.sh
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

echo "=== Preparando el entorno ==="
rm -rf /dist/*
mkdir -p /dist

echo "Descargando código fuente de FFmpeg (versión: $FFMPEG_VERSION)..."
TAR_URL="https://github.com/${FFMPEG_REPO}/archive/${FFMPEG_VERSION}.tar.gz"

mkdir -p /app/ffmpeg
cd /app/ffmpeg

curl -sL "$TAR_URL" | tar xz --strip-components=1

if [ ! -f "configure" ]; then
  echo "❌ Error: No se pudo extraer el código fuente correctamente desde $TAR_URL"
  exit 1
fi

# ==========================================
# FUNCIONES DE COMPILACIÓN
# ==========================================

build_linux() {
    echo "=================================================="
    echo " Compilando Linux (x86_64) - Estático"
    echo "=================================================="

    local LIBS_PREFIX="$COMPILATION_DIR/linux_x86_64"
    local -x PKG_CONFIG_PATH="$LIBS_PREFIX/lib/pkgconfig:$LIBS_PREFIX/share/pkgconfig"

    cd /app/ffmpeg
    make distclean >/dev/null 2>&1 || true

    local feature_flags="--enable-libx264 --enable-libx265  --enable-libvpl --enable-vaapi --enable-opencl --enable-libfreetype --enable-libfribidi --enable-libharfbuzz --enable-libass --enable-libdav1d --enable-libsoxr --enable-libxml2 --enable-libssh --enable-libsvtav1 --enable-vulkan"

    ./configure \
        --prefix="$LIBS_PREFIX" \
        --pkg-config-flags=--static \
        --enable-gpl \
        --enable-version3 \
        --enable-static --disable-shared \
        --disable-debug \
        --disable-ffplay \
        --disable-doc \
        $feature_flags

    make -j"$(nproc)"

    mkdir -p /dist/linux-x86_64
    cp ffmpeg /dist/linux-x86_64/ffmpeg
    cp ffprobe /dist/linux-x86_64/ffprobe
}

build_windows() {
    echo "=================================================="
    echo " Compilando Windows (x86_64-mingw32) - Estático"
    echo "=================================================="

    local LIBS_PREFIX="$COMPILATION_DIR/windows_x86_64"
    local WIN_SYSROOT_BASE="$COMPILATION_DIR/windows_x86_64"
    local WIN_SYSROOT="$WIN_SYSROOT_BASE"
    local WIN_PKG_CONFIG_LIBDIR="$WIN_SYSROOT/lib/pkgconfig:$WIN_SYSROOT/share/pkgconfig:$LIBS_PREFIX/lib/pkgconfig"

    local -x CROSS_PREFIX="x86_64-w64-mingw32-"
    local -x PKG_CONFIG_PATH="$WIN_PKG_CONFIG_LIBDIR"
    local -x PKG_CONFIG_LIBDIR="$WIN_PKG_CONFIG_LIBDIR"
    # export PKG_CONFIG_SYSROOT_DIR

    local -x PKG_CONFIG="/usr/local/bin/pkg-config-win-static.sh"

    cd /app/ffmpeg
    make distclean >/dev/null 2>&1 || true

    local feature_flags="--enable-libx264 --enable-libx265  --enable-libvpl --enable-libfreetype --enable-libfribidi --enable-libharfbuzz --enable-libass --enable-libdav1d --enable-libsoxr --enable-libxml2 --enable-libssh --enable-libsvtav1 --enable-vulkan --enable-ffnvcodec --enable-nvenc --enable-amf"

    local optflags="-O1"

    ./configure \
        --target-os=mingw32 \
        --arch=x86_64 \
        --cross-prefix=$CROSS_PREFIX \
        --prefix="$LIBS_PREFIX" \
        --pkg-config=$PKG_CONFIG \
        --pkg-config-flags="--static" \
        --enable-gpl \
        --enable-version3 \
        --disable-w32threads \
        --enable-pthreads \
        --enable-static --disable-shared \
        --disable-debug --disable-doc --disable-manpages --disable-htmlpages \
        --disable-ffplay \
        --optflags="$optflags" \
        --extra-cflags="-static -std=gnu11 -I$LIBS_PREFIX/include -I$WIN_SYSROOT/include -DLIBSSH_STATIC" \
        --extra-ldflags="-static -static-libgcc -static-libstdc++ -L$LIBS_PREFIX/lib -L$WIN_SYSROOT/lib -pthread" \
        --extra-libs="-static-libgcc -static-libstdc++ -lcompatstat64 -lgomp -lssl -lcrypto -lz -lws2_32 -lcrypt32 -liconv -lgdi32 -lbcrypt -liphlpapi -lmingwex -lucrtbase -lstdc++ -lwinpthread" \
        $feature_flags

    make -j"$(nproc)"

    mkdir -p /dist/windows_x86_64
    cp ffmpeg.exe /dist/windows_x86_64/ffmpeg.exe
    cp ffprobe.exe /dist/windows_x86_64/ffprobe.exe
}

build_android() {
    local ABI=$1
    echo "=================================================="
    echo " Compilando Android: $ABI"
    echo "=================================================="

    local arch_extra_flags=""
    local neon_flag=""
    local optflags="-O3"
    local TARGET_HOST="" ARCH="" CPU=""
    
    case "$ABI" in
        arm64-v8a)
            TARGET_HOST="aarch64-linux-android"
            ARCH="aarch64"
            CPU=""
            neon_flag="--enable-neon"
            ;;
        armeabi-v7a)
            TARGET_HOST="armv7a-linux-androideabi"
            ARCH="arm"
            CPU="armv7-a"
            neon_flag="--enable-neon"
            optflags="-O1"
            ;;
        x86)
            TARGET_HOST="i686-linux-android"
            ARCH="x86"
            CPU=""
            arch_extra_flags="--disable-x86asm --disable-asm"
            ;;
        x86_64)
            TARGET_HOST="x86_64-linux-android"
            ARCH="x86_64"
            CPU=""
            arch_extra_flags="--disable-x86asm"
            optflags="-O1"
            ;;
    esac

    local -x AR=$TOOLCHAIN/bin/llvm-ar
    local -x CC=$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang
    local -x CXX=$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang++
    local -x AS=$CC
    local -x ASFLAGS="-c"
    local -x LD=$CC
    local -x RANLIB=$TOOLCHAIN/bin/llvm-ranlib
    local -x STRIP=$TOOLCHAIN/bin/llvm-strip

    local PREFIX="$COMPILATION_DIR/android_$ABI"
    local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
    local -x PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

    cd /app/ffmpeg
    make distclean >/dev/null 2>&1 || true

    local feature_flags="--enable-libx264 --enable-libx265 --enable-zlib  --enable-openssl --enable-libxml2 --enable-libfreetype --enable-libfribidi --enable-fontconfig --enable-libharfbuzz --enable-libass --enable-libdav1d --enable-libvpx --enable-libwebp --enable-libopenjpeg --enable-libzimg --enable-libsoxr --enable-libmp3lame --enable-libopus --enable-libsvtav1 --enable-libvidstab --enable-libsrt --enable-amf --enable-ffnvcodec --enable-nvenc --enable-mediacodec --enable-jni"

    ./configure \
        --prefix="$PREFIX" \
        --target-os=android \
        --arch="$ARCH" \
        ${CPU:+--cpu="$CPU"} \
        --cc="$CC" \
        --cxx="$CXX" \
        --ar="$AR" \
        --ranlib="$RANLIB" \
        --strip="$STRIP" \
        --enable-cross-compile \
        --pkg-config-flags="--static" \
        --extra-libs="-lm -Wl,-Bstatic -lc++_static -Wl,-Bdynamic -latomic" \
        --enable-static \
        --disable-shared \
        --enable-gpl \
        --enable-version3 \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --optflags="$optflags" \
        ${neon_flag:+$neon_flag} \
        $arch_extra_flags \
        $feature_flags

    # Force static libc++ so ffmpeg does not depend on libc++_shared.so
    sed -i 's/-lstdc++/-lc++_static -lc++abi -lunwind/g; s/-lc++ /-lc++_static /g; s/-lc++$/-lc++_static/g' ffbuild/config.mak

    make -j"$(nproc)"

    local OUT_DIR="/dist/android-$ABI"
    mkdir -p "$OUT_DIR"
    cp ffmpeg "$OUT_DIR/ffmpeg"
    cp ffprobe "$OUT_DIR/ffprobe"
}

# ==========================================
# ORQUESTADOR (SWITCH DE PARÁMETROS)
# ==========================================

echo ">> Objetivo seleccionado: SO=[$TARGET_OS] | Arquitectura=[$TARGET_ARCH]"

case "$TARGET_OS" in
linux)
  build_linux
  ;;
windows)
  build_windows
  ;;
android)
  if [ "$TARGET_ARCH" == "all" ]; then
    build_android "arm64-v8a"
    build_android "armeabi-v7a"
    build_android "x86"
    build_android "x86_64"
  else
    case "$TARGET_ARCH" in
    arm64-v8a|armeabi-v7a|x86|x86_64) build_android "$TARGET_ARCH" ;;
    *)
      echo "❌ Arquitectura de Android no válida: $TARGET_ARCH"
      exit 1
      ;;
    esac
  fi
  ;;
all)
  build_linux
  build_windows
  build_android "arm64-v8a"
  build_android "armeabi-v7a"
  build_android "x86"
  build_android "x86_64"
  ;;
*)
  echo "❌ Sistema operativo no válido: $TARGET_OS"
  exit 1
  ;;
esac

echo "=== Proceso completado exitosamente ==="
echo "Los binarios están listos en /dist"
