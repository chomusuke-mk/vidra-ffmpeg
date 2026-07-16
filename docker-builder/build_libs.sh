#!/bin/bash
set -euo pipefail

SRC_ROOT="$(realpath "$1")"
COMPILATION_DIR="$(realpath "$2")"
TEMP_DIR="$(realpath "$3")"
TARGET_OS=${4:-"all"}
TARGET_ARCH=${5:-"all"}

API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

build_cmake() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with CMake"
	mkdir -p "$dir/build"
	pushd "$dir/build" > /dev/null
	cmake .. -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON "$@"
	make -j"$(nproc)"
	make install
	popd > /dev/null
}

build_meson() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Meson"
	pushd "$dir" > /dev/null
	meson setup build --prefix="$prefix" --libdir="lib" --buildtype=release --default-library=static "$@"
	ninja -C build
	ninja -C build install
	popd > /dev/null
}

build_autotools() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Autotools/Configure"
	pushd "$dir" > /dev/null
	if [ ! -f configure ] && [ -f configure.ac ]; then
		autoreconf -fiv
	fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi
	if [ -f bootstrap ]; then ./bootstrap; fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi
	./configure --prefix="$prefix" --enable-static --disable-shared --with-pic "$@"
	make -j"$(nproc)"
	make install
	popd > /dev/null
}

build_make() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Make"
	pushd "$dir" > /dev/null
	make -j"$(nproc)" PREFIX="$prefix" "$@"
	make install PREFIX="$prefix" "$@"
	popd > /dev/null
}

build_library() {
	local dir="$1"
	local prefix="$2"
	local name=$(basename "$dir")
	echo "--- Compilando $name ---"
	
	# Exceptions for specific libraries
	if [ "$name" == "frei0r" ]; then
		build_cmake "$dir" "$prefix" -DWITHOUT_OPENCV=ON -DWITHOUT_CAIRO=ON -DWITHOUT_GAVL=ON -DWITHOUT_FACERECOGNITION=ON
		return
	fi
	if [ "$name" == "amf" ]; then
		mkdir -p "$prefix/include/AMF"
		cp -r "$dir/AMF/"* "$prefix/include/AMF/" 2>/dev/null || cp -r "$dir/"* "$prefix/include/AMF/"
		return
	fi
	if [ "$name" == "iconv" ]; then
		pushd "$dir" > /dev/null
		./configure --prefix="$prefix" --enable-static --disable-shared --with-pic
		make -j"$(nproc)"
		make install
		popd > /dev/null
		return
	fi
	if [ "$name" == "openssl" ]; then
		pushd "$dir" > /dev/null
		./config --prefix="$prefix" no-shared -fPIC
		make -j"$(nproc)"
		make install_sw
		popd > /dev/null
		return
	fi
	if [ "$name" == "davs2" ] || [ "$name" == "xavs2" ]; then
		pushd "$dir/build/linux" > /dev/null
		./configure --prefix="$prefix" --enable-pic --disable-shared --disable-asm
		make -j"$(nproc)"
		make install
		popd > /dev/null
		return
	fi
	if [ "$name" == "zlib" ] || [ "$name" == "libpng" ]; then
		pushd "$dir" > /dev/null
		./configure --prefix="$prefix" --static
		make -j"$(nproc)"
		make install
		popd > /dev/null
		return
	fi
	if [ "$name" == "x264" ] || [ "$name" == "x265" ]; then
		# x264 uses configure, x265 uses cmake in source/
		if [ "$name" == "x264" ]; then
			pushd "$dir" > /dev/null
			./configure --prefix="$prefix" --enable-static --enable-pic --disable-cli
			make -j"$(nproc)"
			make install
			popd > /dev/null
		else
			pushd "$dir/source" > /dev/null
			cmake . -DCMAKE_INSTALL_PREFIX="$prefix" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
			make -j"$(nproc)"
			make install
			popd > /dev/null
		fi
		return
	fi

	# Generic Detection
	if [ -f "$dir/CMakeLists.txt" ]; then
		build_cmake "$dir" "$prefix"
	elif [ -f "$dir/meson.build" ]; then
		build_meson "$dir" "$prefix"
	elif [ -f "$dir/configure" ] || [ -f "$dir/autogen.sh" ]; then
		build_autotools "$dir" "$prefix"
	elif [ -f "$dir/Makefile" ]; then
		build_make "$dir" "$prefix"
	else
		echo "Warning: No known build system found for $name"
	fi
}

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	local -x PREFIX="$COMPILATION_DIR/linux_x86_64"
	local -x LINUX_ROOT="$TEMP_DIR/linux_x86_64"
	rm -rf "$LINUX_ROOT" &&	mkdir -p "$LINUX_ROOT" &&	cp -r "$SRC_ROOT/"* "$LINUX_ROOT"
	rm -rf "$PREFIX" &&	mkdir -p "$PREFIX"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CFLAGS="-fPIC -O3"
	local -x CXXFLAGS="-fPIC -O3"

	# Dependencies that must be built first
	local PRIORITY_LIBS="dvdread"
	for lib in $PRIORITY_LIBS; do
		if [ -d "$LINUX_ROOT/$lib" ]; then
			build_library "$LINUX_ROOT/$lib" "$PREFIX"
		fi
	done

	for lib_dir in "$LINUX_ROOT"/*; do
		if [ -d "$lib_dir" ]; then
			local name=$(basename "$lib_dir")
			if [[ ! " $PRIORITY_LIBS " =~ " $name " ]]; then
				build_library "$lib_dir" "$PREFIX"
			fi
		fi
	done

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