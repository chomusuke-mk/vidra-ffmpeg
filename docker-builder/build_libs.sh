#!/bin/bash
set -euo pipefail

SRC_ROOT="/build-env/sources"
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	echo "--- Compilando x264 ---"
	pushd "$SRC_ROOT/x264"
	./configure --prefix=/dist/linux_x86_64 --enable-static --disable-shared
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$SRC_ROOT/x265/build/linux"
	
}

