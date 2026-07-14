#!/bin/bash
set -euo pipefail

SRC_ROOT="$(realpath "$1")"
COMPILATION_DIR="$(realpath "$2")"
TARGET_OS="${3:-all}"
TARGET_ARCH="${4:-all}"
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	rm -rf "$COMPILATION_DIR/linux"
	mkdir -p "$COMPILATION_DIR/linux"
	local -x PREFIX="$COMPILATION_DIR/linux"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CFLAGS="-fPIC -O3"
	local -x CXXFLAGS="-fPIC -O3"

	echo "--- Compilando zlib ---"
	pushd "$SRC_ROOT/zlib"
	./configure --prefix="$PREFIX" --static
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x264 ---"
	pushd "$SRC_ROOT/x264"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --enable-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$SRC_ROOT/x265/build/linux"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF ../../source
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libogg ---"
	pushd "$SRC_ROOT/libogg"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvorbis ---"
	pushd "$SRC_ROOT/libvorbis"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando opus ---"
	pushd "$SRC_ROOT/opus"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-extra-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando lame (libmp3lame) ---"
	pushd "$SRC_ROOT/lame"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-frontend
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvpx ---"
	pushd "$SRC_ROOT/libvpx"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --enable-pic --disable-examples --disable-tools --disable-docs --disable-unit-tests
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando freetype ---"
	pushd "$SRC_ROOT/freetype"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-harfbuzz --without-bzip2 --without-brotli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando fribidi ---"
	pushd "$SRC_ROOT/fribidi"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Ddocs=false -Dtests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando harfbuzz ---"
	pushd "$SRC_ROOT/harfbuzz"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Dtests=disabled -Ddocs=disabled -Dfreetype=enabled
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando libass ---"
	pushd "$SRC_ROOT/libass"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-test --disable-libunibreak
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando dav1d ---"
	pushd "$SRC_ROOT/dav1d"
	meson setup build --prefix="$PREFIX" --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando SVT-AV1 ---"
	pushd "$SRC_ROOT/svtav1"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libaom ---"
	pushd "$SRC_ROOT/libaom"
	mkdir -p build_linux_tmp && cd build_linux_tmp
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando brotli ---"
	pushd "$SRC_ROOT/brotli"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libwebp ---"
	pushd "$SRC_ROOT/libwebp"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando openjpeg ---"
	pushd "$SRC_ROOT/openjpeg"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando soxr ---"
	pushd "$SRC_ROOT/soxr"
	cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando zimg ---"
	pushd "$SRC_ROOT/zimg"
	./autogen.sh || true
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libxml2 ---"
	pushd "$SRC_ROOT/libxml2"
	./configure --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-python
	make -j"$(nproc)"
	make install
	popd
}

compile_windows() {
	echo "==================== Compilando librerías - Windows ====================="
	rm -rf "$COMPILATION_DIR/windows_x86_64"
	mkdir -p "$COMPILATION_DIR/windows_x86_64"
	
	local -x PREFIX="$COMPILATION_DIR/windows"
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
	TOOLCHAIN_FILE="$SRC_ROOT/mingw/mingw-toolchain.cmake"
	MESON_CROSS_FILE="$SRC_ROOT/mingw/meson-cross.txt"

	echo "--- Compilando zlib ---"
	pushd "$SRC_ROOT/zlib"
	make -f win32/Makefile.gcc PREFIX=${CROSS_PREFIX}
	INCLUDE_PATH="$PREFIX/include" LIBRARY_PATH="$PREFIX/lib" BINARY_PATH="$PREFIX/bin" make -f win32/Makefile.gcc install
	popd

	echo "--- Compilando x264 ---"
	pushd "$SRC_ROOT/x264"
	./configure --prefix="$PREFIX" --host="$HOST" --cross-prefix="$CROSS_PREFIX" --enable-static --disable-shared
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$SRC_ROOT/x265/build/linux"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF ../../source
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libogg ---"
	pushd "$SRC_ROOT/libogg"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvorbis ---"
	pushd "$SRC_ROOT/libvorbis"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando opus ---"
	pushd "$SRC_ROOT/opus"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --disable-extra-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando lame (libmp3lame) ---"
	pushd "$SRC_ROOT/lame"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --disable-frontend
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvpx ---"
	pushd "$SRC_ROOT/libvpx"
	./configure --prefix="$PREFIX" --target=x86_64-win64-gcc --enable-static --disable-shared --enable-pic --disable-examples --disable-tools --disable-docs --disable-unit-tests
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando freetype ---"
	pushd "$SRC_ROOT/freetype"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --without-harfbuzz --without-bzip2 --without-brotli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando fribidi ---"
	pushd "$SRC_ROOT/fribidi"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Ddocs=false -Dtests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando harfbuzz ---"
	pushd "$SRC_ROOT/harfbuzz"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Dtests=disabled -Ddocs=disabled -Dfreetype=enabled -Dicu=disabled -Dgraphite=disabled -Dgobject=disabled -Dintrospection=disabled -Dglib=disabled
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando libass ---"
	pushd "$SRC_ROOT/libass"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --disable-test --disable-libunibreak --disable-fontconfig --disable-require-system-font-provider
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando dav1d ---"
	pushd "$SRC_ROOT/dav1d"
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando SVT-AV1 ---"
	pushd "$SRC_ROOT/svtav1"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libaom ---"
	pushd "$SRC_ROOT/libaom"
	mkdir -p build_win_tmp && cd build_win_tmp
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando brotli ---"
	pushd "$SRC_ROOT/brotli"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libwebp ---"
	pushd "$SRC_ROOT/libwebp"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando openjpeg ---"
	pushd "$SRC_ROOT/openjpeg"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando soxr ---"
	pushd "$SRC_ROOT/soxr"
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF .
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando zimg ---"
	pushd "$SRC_ROOT/zimg"
	./autogen.sh || true
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libxml2 ---"
	pushd "$SRC_ROOT/libxml2"
	./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --without-python
	make -j"$(nproc)"
	make install
	popd
}

compile_android() {
	local ABI="$1"
	echo "==================== Compilando librerías - Android $ABI ====================="
	rm -rf "$COMPILATION_DIR/android_$ABI"
	mkdir -p "$COMPILATION_DIR/android_$ABI"
	local -x PREFIX="$COMPILATION_DIR/android_$ABI"
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
	
	local -x CFLAGS="-fPIE -fPIC -O3"
	local -x CXXFLAGS="-fPIE -fPIC -O3"
	local -x LDFLAGS="-fPIE -pie"
	
	if [ "$ABI" = "x86" ]; then
		CFLAGS="-fPIE -fPIC -O1"
		CXXFLAGS="-fPIE -fPIC -O1"
	fi

	local TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
	local MESON_CROSS_FILE="$SRC_ROOT/android/$ABI/meson-cross.txt"

	echo "--- Compilando zlib ---"
	pushd "$SRC_ROOT/zlib"
	make distclean >/dev/null 2>&1 || true
	./configure --prefix="$PREFIX" --static --archs=-fPIC
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x264 ---"
	pushd "$SRC_ROOT/x264"
	make distclean >/dev/null 2>&1 || true
	./configure --prefix="$PREFIX" --host="$TARGET_HOST" --cross-prefix="$TOOLCHAIN/bin/llvm-" --enable-static --disable-shared --disable-asm --enable-pic --disable-cli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando x265 ---"
	pushd "$SRC_ROOT/x265/build/linux"
	rm -rf CMakeCache.txt CMakeFiles
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_ASSEMBLY=OFF ../../source
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libogg ---"
	pushd "$SRC_ROOT/libogg"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvorbis ---"
	pushd "$SRC_ROOT/libvorbis"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	if [ "$ABI" = "x86" ]; then
		find . -name Makefile -print0 | xargs -0 sed -i 's/-mno-ieee-fp//g' || true
	fi
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando opus ---"
	pushd "$SRC_ROOT/opus"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-extra-programs
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando lame (libmp3lame) ---"
	pushd "$SRC_ROOT/lame"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-frontend
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libvpx ---"
	pushd "$SRC_ROOT/libvpx"
	make distclean >/dev/null 2>&1 || true
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
	pushd "$SRC_ROOT/freetype"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-harfbuzz --without-bzip2 --without-brotli
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando fribidi ---"
	pushd "$SRC_ROOT/fribidi"
	rm -rf build
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Ddocs=false -Dtests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando harfbuzz ---"
	pushd "$SRC_ROOT/harfbuzz"
	rm -rf build
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Dtests=disabled -Ddocs=disabled -Dfreetype=enabled -Dicu=disabled -Dgraphite=disabled -Dgobject=disabled -Dintrospection=disabled -Dglib=disabled
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando libass ---"
	pushd "$SRC_ROOT/libass"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --disable-test --disable-libunibreak --disable-fontconfig --disable-require-system-font-provider
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando dav1d ---"
	pushd "$SRC_ROOT/dav1d"
	rm -rf build
	meson setup build --cross-file "$MESON_CROSS_FILE" --prefix="$PREFIX" --buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false
	ninja -C build -j"$(nproc)"
	ninja -C build install
	popd

	echo "--- Compilando SVT-AV1 ---"
	pushd "$SRC_ROOT/svtav1"
	rm -rf build_android && mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libaom ---"
	pushd "$SRC_ROOT/libaom"
	mkdir -p build_android_tmp && cd build_android_tmp
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando brotli ---"
	pushd "$SRC_ROOT/brotli"
	rm -rf build_android && mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libwebp ---"
	pushd "$SRC_ROOT/libwebp"
	rm -rf build_android && mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando openjpeg ---"
	pushd "$SRC_ROOT/openjpeg"
	rm -rf build_android && mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando soxr ---"
	pushd "$SRC_ROOT/soxr"
	rm -rf build_android && mkdir -p build_android && cd build_android
	cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API_LEVEL" -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF ..
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando zimg ---"
	pushd "$SRC_ROOT/zimg"
	make distclean >/dev/null 2>&1 || true
	./autogen.sh || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic
	make -j"$(nproc)"
	make install
	popd

	echo "--- Compilando libxml2 ---"
	pushd "$SRC_ROOT/libxml2"
	make distclean >/dev/null 2>&1 || true
	./configure --host="${TARGET_HOST}" --prefix="$PREFIX" --enable-static --disable-shared --with-pic --without-python
	make -j"$(nproc)"
	make install
	popd
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