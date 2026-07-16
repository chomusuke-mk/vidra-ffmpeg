#!/bin/bash
set -euo pipefail

SRC_ROOT="$(realpath "$1")"
COMPILATION_DIR="$(realpath "$2")"
TEMP_DIR="$(realpath "$3")"
TARGET_OS=${4:-"all"}
TARGET_ARCH=${5:-"all"}

API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	local -x PREFIX="$COMPILATION_DIR/linux_x86_64"
	local -x LINUX_ROOT="$TEMP_DIR/linux_x86_64"
	rm -rf "$LINUX_ROOT" &&	mkdir -p "$LINUX_ROOT" &&	cp -r "$SRC_ROOT/"* "$LINUX_ROOT"
	rm -rf "$PREFIX" &&	mkdir -p "$PREFIX"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CFLAGS="-fPIC -O3"
	local -x CXXFLAGS="-fPIC -O3"

	echo "--- Compilando iconv ---"
	pushd "$LINUX_ROOT/iconv"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd


	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "==================== Compilación completada - Linux ====================="
}

compile_windows() {
	echo "==================== Compilando librerías - Windows ====================="
	local -x PREFIX="$COMPILATION_DIR/windows_x86_64"
	local -x WINDOWS_ROOT="$TEMP_DIR/windows_x86_64"
	rm -rf "$WINDOWS_ROOT" &&	mkdir -p "$WINDOWS_ROOT" &&	cp -r "$SRC_ROOT/"* "$WINDOWS_ROOT"
	rm -rf "$PREFIX" &&	mkdir -p "$PREFIX"
	
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CROSS_PREFIX="x86_64-w64-mingw32-"
	local -x CC="${CROSS_PREFIX}gcc"
	local -x CXX="${CROSS_PREFIX}g++"
	local -x AR="${CROSS_PREFIX}ar"
	local -x RANLIB="${CROSS_PREFIX}ranlib"
	local -x RC="${CROSS_PREFIX}windres"
	local -x HOST="x86_64-w64-mingw32"
	local -x CFLAGS="-fPIC -O3"
	local -x CXXFLAGS="-fPIC -O3"

	# Las cross-files son generadas por patch_deps.sh en $SRC_ROOT/mingw
	TOOLCHAIN_FILE="$WINDOWS_ROOT/windows-toolchain.cmake"
	MESON_CROSS_FILE="$WINDOWS_ROOT/windows-meson-cross.txt"

	echo "--- Compilando iconv ---"
	pushd "$WINDOWS_ROOT/iconv"

	popd

	echo "Archivos de dependencias precompiladas copiados a /mingw64/"
	echo "============ Compilación completada - Windows ====================="
}

compile_android() {
	local ABI="$1"
	echo "==================== Compilando librerías - Android $ABI ====================="
	local -x PREFIX="$COMPILATION_DIR/android_$ABI"
	local -x ANDROID_ROOT="$TEMP_DIR/android_$ABI"
	rm -rf "$ANDROID_ROOT" &&	mkdir -p "$ANDROID_ROOT" &&	cp -r "$SRC_ROOT/"* "$ANDROID_ROOT"
	rm -rf "$PREFIX" &&	mkdir -p "$PREFIX"

	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
	local -x PKG_CONFIG_SYSROOT_DIR="/"
	
	local TARGET_HOST
	case "$ABI" in
		arm64-v8a) TARGET_HOST="aarch64-linux-android";;
		armeabi-v7a) TARGET_HOST="armv7a-linux-androideabi";;
		x86) TARGET_HOST="i686-linux-android";;
		x86_64) TARGET_HOST="x86_64-linux-android";;
	esac

	local -x CC="$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang"
	local -x CXX="$TOOLCHAIN/bin/${TARGET_HOST}${API_LEVEL}-clang++"
	local -x AR="$TOOLCHAIN/bin/llvm-ar"
	local -x RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
	local -x STRIP="$TOOLCHAIN/bin/llvm-strip"
	local -x NM="$TOOLCHAIN/bin/llvm-nm"
	if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "arm64-v8a" ]; then
		local -x AS="$CC"
		local -x ASFLAGS="-c"
	fi
	local -x LD="$CC"
	
	local -x CFLAGS="-fPIE -fPIC -O3"
	local -x CXXFLAGS="-fPIE -fPIC -O3"
	local -x LDFLAGS="-fPIE -pie"
	
	if [ "$ABI" = "x86" ]; then
		CFLAGS="-fPIE -fPIC -O1"
		CXXFLAGS="-fPIE -fPIC -O1"
	fi

	local TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
	local MESON_CROSS_FILE="$ANDROID_ROOT/android-${ABI}-meson-cross.txt"

	echo "--- Compilando iconv ---"
	pushd "$ANDROID_ROOT/iconv"
	./configure --prefix="$PREFIX" --static --archs=-fPIC
	make -j"$(nproc)"
	make install
	popd


	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "==================== Compilación completada - Android $ABI ====================="
}

echo ">> Compilación seleccionada: SO=[$TARGET_OS] | Arquitectura=[$TARGET_ARCH]"

case "$TARGET_OS" in
linux)
	compile_linux
	;;
windows)
	compile_windows
	;;
android)
	if [ "$TARGET_ARCH" == "all" ]; then
		for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
			compile_android "$ABI"
		done
	else
		compile_android "$TARGET_ARCH"
	fi
	;;
all)
	compile_linux
	compile_windows
	for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
		compile_android "$ABI"
	done
	;;
*)
	echo "Sistema operativo objetivo desconocido: $TARGET_OS"
	exit 1
	;;
esac

echo "==================== Compilación completada ====================="
echo "Librerías compiladas y almacenadas en: $COMPILATION_DIR"