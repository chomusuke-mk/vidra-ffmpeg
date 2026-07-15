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

	echo "--- Compilando zlib ---"
	pushd "$LINUX_ROOT/zlib"
	./configure --prefix="$PREFIX" --static
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x264 ---"
	pushd "$LINUX_ROOT/x264"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --enable-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$LINUX_ROOT/x265/build/linux"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF ../../source
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libogg ---"
	pushd "$LINUX_ROOT/libogg"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvorbis ---"
	pushd "$LINUX_ROOT/libvorbis"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando opus ---"
	pushd "$LINUX_ROOT/opus"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-extra-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando lame (libmp3lame) ---"
	pushd "$LINUX_ROOT/lame"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-frontend
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvpx ---"
	pushd "$LINUX_ROOT/libvpx"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --enable-pic --disable-examples --disable-tools --disable-docs --disable-unit-tests
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando freetype ---"
	pushd "$LINUX_ROOT/freetype"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-harfbuzz --without-bzip2 --without-brotli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando fribidi ---"
	pushd "$LINUX_ROOT/fribidi"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Ddocs=false -Dtests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando harfbuzz ---"
	pushd "$LINUX_ROOT/harfbuzz"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Dtests=disabled -Ddocs=disabled -Dfreetype=enabled
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando libass ---"
	pushd "$LINUX_ROOT/libass"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-test --disable-libunibreak
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando dav1d ---"
	pushd "$LINUX_ROOT/dav1d"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando SVT-AV1 ---"
	pushd "$LINUX_ROOT/svtav1"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libaom ---"
	pushd "$LINUX_ROOT/libaom"
	mkdir -p build_linux && cd build_linux
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando brotli ---"
	pushd "$LINUX_ROOT/brotli"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libwebp ---"
	pushd "$LINUX_ROOT/libwebp"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando openjpeg ---"
	pushd "$LINUX_ROOT/openjpeg"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando soxr ---"
	pushd "$LINUX_ROOT/soxr"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando zimg ---"
	pushd "$LINUX_ROOT/zimg"
	./autogen.sh || true
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libxml2 ---"
	pushd "$LINUX_ROOT/libxml2"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-python --without-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Vulkan Headers ---"
	pushd "$LINUX_ROOT/vulkan-headers"
	mkdir -p build_linux && cd build_linux
	cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" ..
	ninja install
	popd

	echo "--- Vulkan Loader ---"
	pushd "$LINUX_ROOT/vulkan-loader"
	mkdir -p build_linux && cd build_linux
	cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" -DVULKAN_HEADERS_INSTALL_DIR="$PREFIX" ..
	ninja install
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

	echo "--- Compilando nv-codec-headers ---"
	pushd "$WINDOWS_ROOT/nv-codec-headers"
	make PREFIX="$PREFIX" install
	popd

	echo "--- Compilando amf ---"
	pushd "$WINDOWS_ROOT/amf"
	mkdir -p build_windows && cd build_windows
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF ..
	make -j"$(nproc)"
	make install
	popd


	echo "--- Copiando pkg-config ---"
	cp "$WINDOWS_ROOT/windows-pkg-config.sh" "$PREFIX/"

	echo "--- Copiando dependencias precompiladas de MSYS2 ---"
	cp -rf "$WINDOWS_ROOT"/mingw/*/* "/mingw64/" 2 >/dev/null || true

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

	echo "--- Compilando zlib ---"
	pushd "$ANDROID_ROOT/zlib"
	./configure --prefix="$PREFIX" --static --archs=-fPIC
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x264 ---"
	pushd "$ANDROID_ROOT/x264"
	./configure --prefix="$PREFIX" --host="$TARGET_HOST" --cross-prefix="$TOOLCHAIN/bin/llvm-" --enable-static --disable-shared --disable-asm --enable-pic --disable-cli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$ANDROID_ROOT/x265/build/linux"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_ASSEMBLY=OFF ../../source
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libogg ---"
	pushd "$ANDROID_ROOT/libogg"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvorbis ---"
	pushd "$ANDROID_ROOT/libvorbis"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando opus ---"
	pushd "$ANDROID_ROOT/opus"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-extra-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando lame (libmp3lame) ---"
	pushd "$ANDROID_ROOT/lame"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-frontend
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvpx ---"
	pushd "$ANDROID_ROOT/libvpx"
	local VPX_TARGET
	case "$ABI" in
		arm64-v8a) VPX_TARGET="arm64-android-gcc" ;;
		armeabi-v7a) VPX_TARGET="armv7-android-gcc" ;;
		x86) VPX_TARGET="x86-android-gcc" ;;
		x86_64) VPX_TARGET="x86_64-android-gcc" ;;
	esac
	local VPX_AS="--as=auto"
	if [ "$ABI" = "x86" ] || [ "$ABI" = "x86_64" ]; then
		VPX_AS="--as=nasm"
	fi
	./configure --prefix="$PREFIX" --target="$VPX_TARGET" --enable-static --disable-shared --enable-pic --disable-examples --disable-tools --disable-docs --disable-unit-tests $VPX_AS
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando freetype ---"
	pushd "$ANDROID_ROOT/freetype"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-harfbuzz --without-bzip2 --without-brotli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando fribidi ---"
	pushd "$ANDROID_ROOT/fribidi"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Ddocs=false -Dtests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando harfbuzz ---"
	pushd "$ANDROID_ROOT/harfbuzz"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Dtests=disabled -Ddocs=disabled -Dfreetype=enabled -Dicu=disabled -Dgraphite=disabled -Dgobject=disabled -Dintrospection=disabled -Dglib=disabled
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando libass ---"
	pushd "$ANDROID_ROOT/libass"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-test --disable-libunibreak --disable-fontconfig --disable-require-system-font-provider
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando dav1d ---"
	pushd "$ANDROID_ROOT/dav1d"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando SVT-AV1 ---"
	pushd "$ANDROID_ROOT/svtav1"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libaom ---"
	pushd "$ANDROID_ROOT/libaom"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando brotli ---"
	pushd "$ANDROID_ROOT/brotli"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libwebp ---"
	pushd "$ANDROID_ROOT/libwebp"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando openjpeg ---"
	pushd "$ANDROID_ROOT/openjpeg"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando soxr ---"
	pushd "$ANDROID_ROOT/soxr"
	mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando zimg ---"
	pushd "$ANDROID_ROOT/zimg"
	./autogen.sh || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libxml2 ---"
	pushd "$ANDROID_ROOT/libxml2"
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-python --without-programs
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