#!/bin/bash
set -euo pipefail

PATCHES_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

echo "================ Aplicando parches ==================="
pushd "$SRC_ROOT"

echo "Parcheando mingw-toolchain"
patch --forward --batch -p0 < "$PATCHES_DIR/mingw-toolchain.patch" || true

echo "Parcheando mingw-meson"
patch --forward --batch -p0 < "$PATCHES_DIR/mingw-meson.patch" || true

echo "Generando archivos cross-compilation para Android (Meson)"
API_LEVEL=24
NDK_TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"

for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
    mkdir -p "android/$ABI"
    
    case "$ABI" in
        arm64-v8a) CPU_FAMILY="aarch64"; CPU="aarch64"; TARGET_HOST="aarch64-linux-android" ;;
        armeabi-v7a) CPU_FAMILY="arm"; CPU="armv7"; TARGET_HOST="armv7a-linux-androideabi" ;;
        x86) CPU_FAMILY="x86"; CPU="i686"; TARGET_HOST="i686-linux-android" ;;
        x86_64) CPU_FAMILY="x86_64"; CPU="x86_64"; TARGET_HOST="x86_64-linux-android" ;;
    esac

    cat <<EOF > "android/$ABI/meson-cross.txt"
[binaries]
c = '${NDK_TOOLCHAIN}/bin/${TARGET_HOST}${API_LEVEL}-clang'
cpp = '${NDK_TOOLCHAIN}/bin/${TARGET_HOST}${API_LEVEL}-clang++'
ar = '${NDK_TOOLCHAIN}/bin/llvm-ar'
strip = '${NDK_TOOLCHAIN}/bin/llvm-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = '${CPU_FAMILY}'
cpu = '${CPU}'
endian = 'little'
EOF
done

popd
echo "================ Parches aplicados ==================="
