#!/bin/bash
set -euo pipefail

trap 'on_error $?' EXIT
on_error() {
	local exit_code=$1
	if [ "$exit_code" -ne 0 ]; then
		if [ -n "${CURRENT_LIB:-}" ] && [ -n "${CURRENT_LOG_FILE:-}" ] && [ -f "$CURRENT_LOG_FILE" ]; then
			echo -e "\n❌ FALLO DETECTADO procesando a '$CURRENT_LIB'. El script se detendrá." >&2
			echo "--- INICIO DE CONTENIDO DE $CURRENT_LOG_FILE ---" >&2
			cat "$CURRENT_LOG_FILE" >&2
			echo "--- FIN DE CONTENIDO DE $CURRENT_LOG_FILE ---" >&2
		fi
	fi
}

SRC_ROOT="$(realpath "$1")"
COMPILATION_DIR="$(realpath "$2")"
TEMP_DIR="$(realpath "$3")"
LOGS_DIR="$(realpath "$4")"
TARGET_OS=${5:-"all"}
TARGET_ARCH=${6:-"all"}

API_LEVEL=24
TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"

build_cmake() {
	echo "   -> Building with CMake"
	mkdir -p "$BUILDING_DIR/vidra-build"
	pushd "$BUILDING_DIR/vidra-build" >/dev/null
	local toolchain_args=()
	if [ -n "${TOOLCHAIN_FILE:-}" ] && [ -f "$TOOLCHAIN_FILE" ]; then
		toolchain_args+=("-DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE")
		if [ "${TARGET_OS}" == "android" ]; then
			toolchain_args+=("-DANDROID_ABI=$TARGET_ARCH" "-DANDROID_PLATFORM=android-$API_LEVEL")
		fi
	fi
	cmake .. -Wno-dev -DCMAKE_INSTALL_PREFIX="$BUILDING_PREFIX" -DCMAKE_PREFIX_PATH="$BUILDING_PREFIX" "${toolchain_args[@]}" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_TESTING=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DENABLE_DOCS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TESTS=OFF -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF "$@"
	make -j"$(nproc)"
	make install
	popd >/dev/null
}

build_meson() {
	echo "   -> Building with Meson"
	pushd "$BUILDING_DIR" >/dev/null
	local cross_args=()
	if [ -n "${MESON_CROSS_FILE:-}" ]; then
		cross_args=("--cross-file=$MESON_CROSS_FILE")
	fi
	meson setup build --prefix="$BUILDING_PREFIX" "${cross_args[@]}" --libdir="lib" --buildtype=release --default-library=static "$@"
	ninja -C build -j "$(nproc)"
	ninja -C build install
	popd >/dev/null
}

build_autotools() {
	echo "   -> Building with Autotools/Configure"
	pushd "$BUILDING_DIR" >/dev/null
	if [ -f "configure.ac" ]; then
		autoreconf -fiv || true
	fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi
	if [ -f bootstrap ]; then ./bootstrap; fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi

	if [ "${TARGET_OS}" == "android" ]; then
		# Android's pthread is in libc
		if [ -f configure ]; then
			sed -i 's/as_fn_error.*"Unable to link pthread functions".*/ax_pthread_ok=yes/g' configure
		fi
		local -x PTHREAD_LIBS="-lc"
		local -x PTHREAD_CFLAGS=" "
	fi

	./configure --prefix="$BUILDING_PREFIX" --host="$HOST" --enable-static --disable-shared --with-pic --disable-programs --disable-tools --disable-tests --disable-frontend --disable-examples --disable-docs --disable-cli --disable-unit-tests "$@"
	make -j"$(nproc)"
	make install

	popd >/dev/null
}

build_make() {
	echo "   -> Building with Make"
	pushd "$BUILDING_DIR" >/dev/null
	make -j"$(nproc)" PREFIX="$BUILDING_PREFIX" "$@"
	make install PREFIX="$BUILDING_PREFIX" "$@"
	popd >/dev/null
}

build_library() {
	local -x BUILDING_DIR="$1"
	local -x BUILDING_PREFIX="$2"
	local BUILD_TIMES_REF="$3"
	local name
	name=$(basename "$BUILDING_DIR")
	local start_time
	start_time=$(date +%s)

	case "$name" in
	zix) build_meson -Dtests=disabled -Dbenchmarks=disabled ;;
	frei0r) build_cmake -DWITHOUT_OPENCV=ON -DWITHOUT_CAIRO=ON -DWITHOUT_GAVL=ON -DWITHOUT_FACERECOGNITION=ON -DBUILD_TESTING=OFF ;;
	amf) mkdir -p "$BUILDING_PREFIX/include/" && cp -r "$BUILDING_DIR/"* "$BUILDING_PREFIX/include/" ;;
	libopenmpt) build_autotools --without-mpg123 --disable-openmpt123 ;;
	chromaprint) build_cmake -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF -DFFT_LIB=fftw3 -DFFTW3_DIR="$BUILDING_PREFIX" -DFFTW3_INCLUDE_DIR="$BUILDING_PREFIX/include" -DFFTW3_INCLUDE_DIRS="$BUILDING_PREFIX/include" -DFFTW3_LIBRARY="$BUILDING_PREFIX/lib/libfftw3.a" -DFFTW3_LIBRARIES="$BUILDING_PREFIX/lib/libfftw3.a" ;;
	sdl2) build_cmake -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF ;;
	openssl)
		pushd "$BUILDING_DIR" >/dev/null
		if [ "$TARGET_OS" == "windows" ]; then
			./Configure mingw64 --prefix="$BUILDING_PREFIX" --libdir=lib no-shared no-asm no-apps
		elif [ "$TARGET_OS" == "android" ]; then
			local ssl_arch=""
			case "$TARGET_ARCH" in
			arm64-v8a) ssl_arch="android-arm64" ;;
			armeabi-v7a) ssl_arch="android-arm" ;;
			x86) ssl_arch="android-x86" ;;
			x86_64) ssl_arch="android-x86_64" ;;
			esac
			local -x ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
			local -x PATH="$TOOLCHAIN/bin:$PATH"
			./Configure $ssl_arch -D__ANDROID_API__=$API_LEVEL --prefix="$BUILDING_PREFIX" --libdir=lib no-shared no-apps no-docs -fPIC
		else
			./config --prefix="$BUILDING_PREFIX" --libdir=lib no-shared no-apps no-docs -fPIC
		fi
		make -j"$(nproc)"
		make install_sw
		popd >/dev/null
		;;
	libdavs2 | libxavs2) BUILDING_DIR="$BUILDING_DIR/build/linux" build_autotools --disable-asm --extra-cflags="-Wno-incompatible-function-pointer-types" ;;
	libbluray) build_meson -Denable_tools=false -Denable_devtools=false -Denable_examples=false ;;
	libjxl) build_cmake -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_ENABLE_SKIA=OFF -DBUILD_TESTING=OFF -DSJPEG_ANDROID_NDK_PATH="${ANDROID_NDK_HOME}" ;;
	libharfbuzz) build_meson -Dfreetype=enabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dgpu=disabled -Dglib=disabled -Dgobject=disabled -Dicu=disabled ;;
	libfreetype) build_meson -Dharfbuzz=disabled ;;
	fontconfig) build_meson -Dtests=disabled -Dtools=disabled -Ddoc=disabled ;;
	libsndfile) build_cmake -DENABLE_EXTERNAL_LIBS=OFF ;;
	libshaderc) build_cmake -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON ;;
	libsrt) build_cmake -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DENABLE_TESTING=OFF -DENABLE_UNITTESTS=OFF -DUSE_STATIC_LIBSTDCXX=ON ;;
	vulkan-headers)
		local extra_args=()
		if [ "$TARGET_OS" = "linux" ]; then
			extra_args+=("-DCMAKE_INSTALL_SYSCONFDIR=/etc")
		fi
		build_cmake "${extra_args[@]}"
		if [ "$TARGET_OS" = "android" ]; then
			mkdir -p "$BUILDING_PREFIX/lib/pkgconfig"
			cat <<EOF >"$BUILDING_PREFIX/lib/pkgconfig/vulkan.pc"
prefix=$BUILDING_PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: Vulkan
Description: Vulkan Loader (Android NDK)
Version: 1.3.296
Libs: -L\${libdir} -lvulkan
Cflags: -I\${includedir}
EOF
		fi
		;;
	librist)
		local extra_args=()
		[ "$TARGET_OS" == "windows" ] && extra_args+=("-Dhave_mingw_pthreads=true")
		build_meson "${extra_args[@]}" -Dbuilt_tools=false -Dtest=false
		;;
	libx265)
		BUILDING_DIR="$BUILDING_DIR/source"
		local extra_args=()
		[ "${TARGET_OS}" == "android" ] && [ "$TARGET_ARCH" == "x86" ] && extra_args+=("-DENABLE_ASSEMBLY=OFF")
		build_cmake -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON "${extra_args[@]}"
		;;
	libx264)
		local extra_args=("--enable-pic")
		[ "${TARGET_OS}" == "android" ] && [ "$TARGET_ARCH" == "x86" ] && extra_args+=("--disable-asm")
		build_autotools "${extra_args[@]}"
		;;
	lame) build_autotools --disable-decoder ;;
	libuavs3d)
		local extra_args=()
		[ "${TARGET_OS}" == "android" ] && extra_args=("-DCMAKE_THREAD_LIBS_INIT=-lc" "-DCMAKE_HAVE_THREADS_LIBRARY=1" "-DCMAKE_USE_WIN32_THREADS_INIT=0" "-DCMAKE_USE_PTHREADS_INIT=1")
		build_cmake -DCOMPILE_10BIT=0 "${extra_args[@]}"
		;;
	libvorbis) build_cmake -DOGG_LIBRARY="$BUILDING_PREFIX/lib/libogg.a" -DOGG_INCLUDE_DIR="$BUILDING_PREFIX/include" ;;
	libxml2)
		local extra_args=()
		[ "${TARGET_OS}" != "linux" ] && extra_args+=("-DIconv_LIBRARY=$BUILDING_PREFIX/lib/libiconv.a" "-DIconv_INCLUDE_DIR=$BUILDING_PREFIX/include")
		build_cmake "${extra_args[@]}"
		;;
	expat) build_cmake -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_DOCS=OFF ;;
	libpulse)
		local extra_args=()
		[ "${TARGET_OS}" != "linux" ] && extra_args+=("-Dc_link_args=-L$BUILDING_PREFIX/lib -liconv")
		build_meson -Ddatabase=simple -Dtests=false -Dman=false -Dx11=disabled -Ddoxygen=false "${extra_args[@]}"
		;;
	libpng) build_cmake -DZLIB_LIBRARY="$BUILDING_PREFIX/lib/libz.a" -DZLIB_INCLUDE_DIR="$BUILDING_PREFIX/include" -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_EXECUTABLES=OFF ;;
	libvmaf) BUILDING_DIR="$BUILDING_DIR/libvmaf" build_meson -Denable_tests=false -Denable_docs=false ;;
	libvpx)
		local extra_args=()
		if [ "${TARGET_OS}" == "windows" ]; then
			extra_args+=("--target=x86_64-win64-gcc")
		elif [ "${TARGET_OS}" == "android" ]; then
			case "$TARGET_ARCH" in
			arm64-v8a) extra_args+=("--target=arm64-android-gcc") ;;
			armeabi-v7a) extra_args+=("--target=armv7-android-gcc") ;;
			x86) extra_args+=("--target=x86-android-gcc") ;;
			x86_64) extra_args+=("--target=x86_64-android-gcc") ;;
			esac
		fi
		pushd "$BUILDING_DIR" >/dev/null
		./configure --prefix="$BUILDING_PREFIX" "${extra_args[@]}" --enable-pic --disable-examples --disable-unit-tests --disable-tools --disable-docs --disable-shared --enable-static
		make -j"$(nproc)"
		make install
		popd >/dev/null
		;;
	openal) build_cmake -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DLIBTYPE=STATIC -DCMAKE_EXE_LINKER_FLAGS="-lm" ;;
	librav1e)
		(
			pushd "$BUILDING_DIR" >/dev/null
			local cargo_opts=(--no-default-features --features="asm,threading,signal_support,capi")
			if [ -n "${CROSS_PREFIX:-}" ] && [[ "${CROSS_PREFIX}" == *"mingw"* ]]; then
				rustup target add x86_64-pc-windows-gnu || true
				cargo_opts+=(--target="x86_64-pc-windows-gnu")
				local -x CC_x86_64_pc_windows_gnu="${CC}"
				local -x CXX_x86_64_pc_windows_gnu="${CXX}"
				local -x AR_x86_64_pc_windows_gnu="${AR}"
				local -x CFLAGS_x86_64_pc_windows_gnu="${CFLAGS}"
				local -x CXXFLAGS_x86_64_pc_windows_gnu="${CXXFLAGS}"
				local -x CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${CC}"
				unset CC CXX AR RANLIB RC CFLAGS CXXFLAGS LDFLAGS HOST
			elif [ "${TARGET_OS}" == "android" ]; then
				local RUST_TARGET=""
				case "$TARGET_ARCH" in
				arm64-v8a) RUST_TARGET="aarch64-linux-android" ;;
				armeabi-v7a) RUST_TARGET="armv7-linux-androideabi" ;;
				x86) RUST_TARGET="i686-linux-android" ;;
				x86_64) RUST_TARGET="x86_64-linux-android" ;;
				esac
				rustup target add $RUST_TARGET || true
				cargo_opts+=(--target="$RUST_TARGET")
				local -x CARGO_TARGET_"$(echo "$RUST_TARGET" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"_LINKER="${CC}"
			fi
			cargo cinstall --release --lib --prefix="$BUILDING_PREFIX" --libdir="lib" --library-type=staticlib "${cargo_opts[@]}"
			if [ -f "$BUILDING_PREFIX/lib/pkgconfig/rav1e.pc" ]; then
				local content
				content=$(cat "$BUILDING_PREFIX/lib/pkgconfig/rav1e.pc")
				content="${content//-lgcc_s/}"
				content="${content//-lc /}"
				echo "$content" >"$BUILDING_PREFIX/lib/pkgconfig/rav1e.pc"
			fi
			popd >/dev/null
		)
		;;
	libopenh264)
		local args=("PREFIX=$BUILDING_PREFIX" "INCLUDE_PREFIX=$BUILDING_PREFIX/include")
		if [ "${TARGET_OS}" == "android" ]; then
			args+=("OS=android" "NDKROOT=$ANDROID_NDK_HOME" "TARGET=android-$API_LEVEL" "NDKLEVEL=$API_LEVEL")
			if [ "$TARGET_ARCH" == "arm64-v8a" ]; then
				args+=("ARCH=arm64")
			elif [ "$TARGET_ARCH" == "armeabi-v7a" ]; then
				args+=("ARCH=arm")
			elif [ "$TARGET_ARCH" == "x86" ]; then
				args+=("ARCH=x86" "USE_ASM=No")
			elif [ "$TARGET_ARCH" == "x86_64" ]; then
				args+=("ARCH=x86_64")
			fi
		elif [ "${TARGET_OS}" == "windows" ]; then
			args+=("OS=mingw_nt" "ARCH=$TARGET_ARCH" "CC=${CC}" "CXX=${CXX}" "AR=${AR}")
		fi
		build_make libraries "${args[@]}"
		build_make install "${args[@]}"
		;;
	libtheora) build_autotools --disable-spec --disable-asm --disable-maintainer-mode ;;
	libplacebo) build_meson -Ddemos=false ;;
	zlib)
		build_cmake -DBUILD_SHARED_LIBS=OFF
		if [ -f "$BUILDING_PREFIX/lib/libzs.a" ]; then
			mv "$BUILDING_PREFIX/lib/libzs.a" "$BUILDING_PREFIX/lib/libz.a"
		fi
		if [ -f "$BUILDING_PREFIX/lib/libzlibstatic.a" ]; then
			mv "$BUILDING_PREFIX/lib/libzlibstatic.a" "$BUILDING_PREFIX/lib/libz.a"
		fi
		;;
	libsoxr) build_cmake -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF ;;
	libssh) build_cmake -DBUILD_SHARED_LIBS=OFF -DWITH_EXAMPLES=OFF -DWITH_SERVER=OFF -DWITH_GSSAPI=OFF -DZLIB_LIBRARY="$BUILDING_PREFIX/lib/libz.a" -DZLIB_INCLUDE_DIR="$BUILDING_PREFIX/include" -DCMAKE_C_FLAGS="-I$BUILDING_PREFIX/include" ;;
	opencl-icd-loader)
		build_cmake -DBUILD_SHARED_LIBS=OFF -DOPENCL_ICD_LOADER_HEADERS_DIR="$BUILDING_PREFIX/include"
		if [ -f "$BUILDING_PREFIX/lib/OpenCL.a" ]; then
			mv "$BUILDING_PREFIX/lib/OpenCL.a" "$BUILDING_PREFIX/lib/libOpenCL.a"
		fi
		;;
	libzvbi)
		local -x LIBS="-lm"
		local -x ac_cv_func_malloc_0_nonnull=yes
		local -x ac_cv_func_realloc_0_nonnull=yes
		build_autotools --without-x --disable-proxy
		;;
	libvvenc)
		local extra_args=()
		[ "${TARGET_OS}" == "windows" ] && extra_args+=("-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF" "-DVVENC_ENABLE_LTO=OFF")
		[ "${TARGET_OS}" == "android" ] && [ "$TARGET_ARCH" == "x86" ] && extra_args+=("-DVVENC_ENABLE_X86_SIMD=OFF")
		build_cmake "${extra_args[@]}" -DBUILD_SHARED_LIBS=OFF -DVVENC_ENABLE_WERROR=OFF
		;;
	libass)
		local extra_args=()
		[ "${TARGET_OS}" == "android" ] && [[ "$TARGET_ARCH" == *"x86"* ]] && extra_args=("-Dasm=disabled")
		build_meson "${extra_args[@]}"
		;;
	libxvid)
		BUILDING_DIR="$BUILDING_DIR/build/generic"
		local extra_args=()
		[ "${TARGET_OS}" == "android" ] && [ "$TARGET_ARCH" == "x86" ] && extra_args+=("--disable-assembly")
		build_autotools "${extra_args[@]}"
		mv "$BUILDING_PREFIX/lib/xvidcore.a" "$BUILDING_PREFIX/lib/libxvidcore.a" || true
		;;
	libzmq) build_cmake -DCMAKE_SYSTEM_VERSION=6.1 -DPOLLER=epoll -DWITH_TLS=OFF -DBUILD_TESTS=OFF -DWITH_DOCS=OFF -DENABLE_DRAFTS=OFF -DBUILD_SHARED=OFF ;;
	libva) build_meson -Ddriverdir=/usr/lib/x86_64-linux-gnu/dri ;;
	libdav1d) build_meson -Dtestdata_tests=false -Denable_docs=false ;;
	xlib_deps)
		cp /usr/lib/x86_64-linux-gnu/libXv.a "$BUILDING_PREFIX/lib/" || true
		cp /usr/lib/x86_64-linux-gnu/libXext.a "$BUILDING_PREFIX/lib/" || true
		cp /usr/lib/x86_64-linux-gnu/libxcb.a "$BUILDING_PREFIX/lib/" || true
		cp /usr/lib/x86_64-linux-gnu/libXau.a "$BUILDING_PREFIX/lib/" || true
		cp /usr/lib/x86_64-linux-gnu/libXdmcp.a "$BUILDING_PREFIX/lib/" || true
		cp /usr/lib/x86_64-linux-gnu/libXfixes.a "$BUILDING_PREFIX/lib/" || true
		;;
	*)
		if [ -f "$BUILDING_DIR/meson.build" ]; then
			build_meson
		elif [ -f "$BUILDING_DIR/CMakeLists.txt" ]; then
			build_cmake
		elif [ -f "$BUILDING_DIR/configure" ] || [ -f "$BUILDING_DIR/autogen.sh" ] || [ -f "$BUILDING_DIR/configure.ac" ]; then
			build_autotools
		elif [ -f "$BUILDING_DIR/Makefile" ]; then
			build_make
		else
			echo "Error libreria $name desconocida y no se pudo determinar el sistema de compilacion"
			return 1
		fi
		;;
	esac
	local end_time
	end_time=$(date +%s)
	local duration=$((end_time - start_time))
	if [[ -n "$BUILD_TIMES_REF" ]]; then
		declare -n ref_times="$BUILD_TIMES_REF"
		ref_times+=("$duration")
	fi
}

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	local -x TARGET_OS="linux"
	local -x TARGET_ARCH="x86_64"
	local -x PREFIX="$COMPILATION_DIR/linux-x86_64"
	local -x BUILD_ROOT="$TEMP_DIR/linux-x86_64"
	local -x LOGS_ROOT="$LOGS_DIR/linux-x86_64"
	rm -rf "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT" && mkdir -p "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT"
	cp -r "$SRC_ROOT/"* "$BUILD_ROOT"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x HOST="x86_64-linux-gnu"
	local -x CFLAGS="-fPIC -O3 -I$PREFIX/include"
	local -x CXXFLAGS="-fPIC -O3 -I$PREFIX/include"
	local -x LDFLAGS="-L$PREFIX/lib"

	# Dependencies that must be built first
	local LIBS=(
		"libsndfile"
		"libudfread"
		"libdvdread"
		"lv2"
		"zix"
		"serd"
		"sord"
		"sratom"
		"lilv"
		"libogg"
		"vulkan-headers"
		"vulkan-loader"
		"opencl-headers"
		"opencl-icd-loader"
		"nv-codec-headers"
		"zlib"
		"libpng"
		"libxml2"
		"libvmaf"
		"expat"
		"libfreetype"
		"fontconfig"
		"libharfbuzz"
		"libfribidi"
		"libvorbis"
		"gmp"
		"lzma"
		"liblcevc"
		"amf"
		"libaom"
		"libaribb24"
		"avisynth"
		"fftw"
		"chromaprint"
		"libdav1d"
		"libdavs2"
		"libdvdnav"
		"frei0r"
		"libgme"
		"libkvazaar"
		"libaribcaption"
		"libunibreak"
		"libass"
		"libbluray"
		"libjxl"
		"lame"
		"libopus"
		"libplacebo"
		"openssl"
		"librist"
		"libssh"
		"libtheora"
		"libvpx"
		"libwebp"
		"libzmq"
		"libvpl"
		"openal"
		"liboapv"
		"opencore-amr"
		"libopenh264"
		"libopenjpeg"
		"libopenmpt"
		"librav1e"
		"librubberband"
		"sdl2"
		"libsnappy"
		"libsrt"
		"libsvtav1"
		"libtwolame"
		"libuavs3d"
		"libva"
		"libvidstab"
		"libvvenc"
		"libx264"
		"libx265"
		"libxavs2"
		"libxvid"
		"libzimg"
		"libzvbi"
		"libsoxr"
		"libxcb"
		"xlib"
		"xlib_deps"
		"libpulse"
		"libdrm"
	)

	local BUILD_TIMES=()
	for lib in "${LIBS[@]}"; do
		echo "--> Compilando $lib"
		CURRENT_LIB="$lib"
		CURRENT_LOG_FILE="$LOGS_ROOT/$lib.log"
		build_library "$BUILD_ROOT/$lib" "$PREFIX" "BUILD_TIMES" >"$CURRENT_LOG_FILE" 2>&1
		CURRENT_LIB=""
		CURRENT_LOG_FILE=""
	done

	find "$PREFIX/lib" -name "*.so*" -delete || true
	for a_file in "$PREFIX/lib"/*.a; do
		libname=$(basename "$a_file" .a)
		if [ "$libname" = "libgmp" ] || [ "$libname" = "libz" ] || [ "$libname" = "libzstd" ] || [ "$libname" = "liblzma" ] || [ "$libname" = "libxml2" ]; then
			continue
		fi
		rm -f "/usr/lib/x86_64-linux-gnu/${libname}.so"* || true
	done

	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "---- Tiempos de compilación por librería ----"
	for i in "${!LIBS[@]}"; do
		printf "%-20s : %d s\n" "${LIBS[$i]}" "${BUILD_TIMES[$i]}"
	done
	echo "==================== Compilación completada - Linux ====================="
}

compile_windows() {
	echo "==================== Compilando librerías - Windows ====================="
	local -x TARGET_OS="windows"
	local -x TARGET_ARCH="x86_64"
	local -x PREFIX="$COMPILATION_DIR/windows-x86_64"
	local -x BUILD_ROOT="$TEMP_DIR/windows-x86_64"
	local -x LOGS_ROOT="$LOGS_DIR/windows-x86_64"
	rm -rf "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT" && mkdir -p "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT"
	cp -r "$SRC_ROOT/"* "$BUILD_ROOT"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CROSS_PREFIX="x86_64-w64-mingw32-"
	bash "${BUILD_ROOT}/windows-create-pkg-config.sh" "$CROSS_PREFIX" "$PKG_CONFIG_PATH" "$PKG_CONFIG_LIBDIR"
	local -x CC="${CROSS_PREFIX}gcc"
	local -x CXX="${CROSS_PREFIX}g++"
	local -x AR="${CROSS_PREFIX}ar"
	local -x RANLIB="${CROSS_PREFIX}ranlib"
	local -x STRIP="${CROSS_PREFIX}strip"
	local -x RC="${CROSS_PREFIX}windres"
	local -x HOST="x86_64-w64-mingw32"
	local -x CFLAGS="-fPIC -O3 -I$PREFIX/include"
	local -x CXXFLAGS="-fPIC -O3 -I$PREFIX/include"
	local -x LDFLAGS="-L$PREFIX/lib"

	# Las cross-files son generadas por patch_deps.sh en $SRC_ROOT/mingw
	local -x TOOLCHAIN_FILE="$BUILD_ROOT/windows-toolchain.cmake"
	local -x MESON_CROSS_FILE="$BUILD_ROOT/windows-meson-cross.txt"

	local LIBS=(
		"libsndfile"
		"libudfread"
		"libdvdread"
		"lv2"
		"zix"
		"serd"
		"sord"
		"sratom"
		"lilv"
		"libogg"
		"vulkan-headers"
		"vulkan-loader"
		"opencl-headers"
		"opencl-icd-loader"
		"nv-codec-headers"
		"iconv"
		"zlib"
		"libpng"
		"libxml2"
		"libvmaf"
		"expat"
		"libfreetype"
		"fontconfig"
		"libharfbuzz"
		"libfribidi"
		"libvorbis"
		"gmp"
		"lzma"
		"liblcevc"
		"amf"
		"libaom"
		"libaribb24"
		"avisynth"
		"fftw"
		"chromaprint"
		"libdav1d"
		"libdavs2"
		"libdvdnav"
		"frei0r"
		"libgme"
		"libkvazaar"
		"libaribcaption"
		"libunibreak"
		"libass"
		"libbluray"
		"libjxl"
		"lame"
		"libopus"
		"libplacebo"
		"librist"
		"openssl"
		"libssh"
		"libtheora"
		"libvpx"
		"libwebp"
		"libzmq"
		"libvpl"
		"openal"
		"liboapv"
		"opencore-amr"
		"libopenh264"
		"libopenjpeg"
		"libopenmpt"
		"librav1e"
		"librubberband"
		"sdl2"
		"libsnappy"
		"libsrt"
		"libsvtav1"
		"libtwolame"
		"libuavs3d"
		"libvidstab"
		"libvvenc"
		"libx264"
		"libx265"
		"libxavs2"
		"libxvid"
		"libzimg"
		"libzvbi"
		"libsoxr"
	)

	local BUILD_TIMES=()
	for lib in "${LIBS[@]}"; do
		echo "--> Compilando $lib"
		CURRENT_LIB="$lib"
		CURRENT_LOG_FILE="$LOGS_ROOT/$lib.log"
		build_library "$BUILD_ROOT/$lib" "$PREFIX" "BUILD_TIMES" >"$CURRENT_LOG_FILE" 2>&1
		CURRENT_LIB=""
		CURRENT_LOG_FILE=""
	done

	cp "$SRC_ROOT/windows-pkg-config.sh" "$PREFIX/windows-pkg-config.sh"

	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "---- Tiempos de compilación por librería ----"
	for i in "${!LIBS[@]}"; do
		printf "%-20s : %d s\n" "${LIBS[$i]}" "${BUILD_TIMES[$i]}"
	done
	echo "============ Compilación completada - Windows ============"
}

compile_android() {
	local -x TARGET_ARCH="$1"
	echo "==================== Compilando librerías - Android $TARGET_ARCH ====================="
	local -x TARGET_OS="android"
	local -x PREFIX="$COMPILATION_DIR/android-$TARGET_ARCH"
	local -x BUILD_ROOT="$TEMP_DIR/android-$TARGET_ARCH"
	local -x LOGS_ROOT="$LOGS_DIR/android-$TARGET_ARCH"
	rm -rf "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT" && mkdir -p "$BUILD_ROOT" "$PREFIX" "$LOGS_ROOT"
	cp -r "$SRC_ROOT/"* "$BUILD_ROOT"

	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
	local -x PKG_CONFIG_SYSROOT_DIR="/"

	local HOST
	case "$TARGET_ARCH" in
	arm64-v8a) HOST="aarch64-linux-android" ;;
	armeabi-v7a) HOST="armv7a-linux-androideabi" ;;
	x86) HOST="i686-linux-android" ;;
	x86_64) HOST="x86_64-linux-android" ;;
	esac

	local -x CC="$TOOLCHAIN/bin/${HOST}${API_LEVEL}-clang"
	local -x CXX="$TOOLCHAIN/bin/${HOST}${API_LEVEL}-clang++"
	local -x AR="$TOOLCHAIN/bin/llvm-ar"
	local -x RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
	local -x STRIP="$TOOLCHAIN/bin/llvm-strip"
	local -x NM="$TOOLCHAIN/bin/llvm-nm"
	if [ "$TARGET_ARCH" = "armeabi-v7a" ] || [ "$TARGET_ARCH" = "arm64-v8a" ]; then
		local -x AS="$CC"
		local -x ASFLAGS="-c"
	fi
	local -x LD="$CC"

	local -x CFLAGS="-fPIE -fPIC -O3 -I$PREFIX/include"
	local -x CXXFLAGS="-fPIE -fPIC -O3 -I$PREFIX/include"
	local -x LDFLAGS="-fPIE -pie -L$PREFIX/lib"

	if [ "$TARGET_ARCH" = "x86" ]; then
		CFLAGS="-fPIE -fPIC -O1 -I$PREFIX/include"
		CXXFLAGS="-fPIE -fPIC -O1 -I$PREFIX/include"
	fi

	local -x TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
	local -x MESON_CROSS_FILE="$BUILD_ROOT/android-${TARGET_ARCH}-meson-cross.txt"

	local LIBS=(
		"libudfread"
		"libdvdread"
		"lv2"
		"zix"
		"serd"
		"sord"
		"sratom"
		"lilv"
		"libogg"
		"iconv"
		"zlib"
		"libpng"
		"libxml2"
		"libvmaf"
		"expat"
		"libfreetype"
		"fontconfig"
		"libharfbuzz"
		"libfribidi"
		"libvorbis"
		"gmp"
		"lzma"
		"liblcevc"
		"vulkan-headers"
		"libaom"
		"libaribb24"
		"avisynth"
		"fftw"
		"chromaprint"
		"libdav1d"
		"libdavs2"
		"libdvdnav"
		"frei0r"
		"libgme"
		"libkvazaar"
		"libaribcaption"
		"libunibreak"
		"libass"
		"libbluray"
		"libjxl"
		"lame"
		"libopus"
		"libplacebo"
		"openssl"
		"librist"
		"libssh"
		"libtheora"
		"libvpx"
		"libwebp"
		"libzmq"
		"libvpl"
		"openal"
		"liboapv"
		"opencore-amr"
		"libopenh264"
		"libopenjpeg"
		"libopenmpt"
		"librav1e"
		"librubberband"
		"sdl2"
		"libsnappy"
		"libsrt"
		"libsvtav1"
		"libtwolame"
		"libuavs3d"
		"libvidstab"
		"libvvenc"
		"libx264"
		"libx265"
		"libxavs2"
		"libxvid"
		"libzimg"
		"libzvbi"
		"libsoxr"
	)

	local BUILD_TIMES=()
	for lib in "${LIBS[@]}"; do
		echo "--> Compilando $lib"
		CURRENT_LIB="$lib"
		CURRENT_LOG_FILE="$LOGS_ROOT/$lib.log"
		build_library "$BUILD_ROOT/$lib" "$PREFIX" "BUILD_TIMES" >"$CURRENT_LOG_FILE" 2>&1
		CURRENT_LIB=""
		CURRENT_LOG_FILE=""
	done

	# Delete any accidentally generated shared libraries
	find "$PREFIX/lib" -name "*.so*" -delete || true

	# Clean up pc files on Android
	find "$PREFIX/lib/pkgconfig" -name "*.pc" -type f -exec sed -i -e 's/-lpthread//g' -e 's/-l-pthread//g' -e 's/-pthread//g' -e 's/-lrt//g' -e 's/-lexecinfo//g' -e 's/libexecinfo\.a//g' -e 's/-lunwind//g' -e 's/libunwind\.a//g' -e 's/-l: //g' -e 's/-l-ldl//g' {} + || true

	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "---- Tiempos de compilación por librería ----"
	for i in "${!LIBS[@]}"; do
		printf "%-20s : %d s\n" "${LIBS[$i]}" "${BUILD_TIMES[$i]}"
	done
	echo "==================== Compilación completada - Android $TARGET_ARCH ====================="
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
		compile_android "arm64-v8a"
		compile_android "armeabi-v7a"
		compile_android "x86"
		compile_android "x86_64"
	else
		compile_android "$TARGET_ARCH"
	fi
	;;
all)
	compile_windows
	compile_android "arm64-v8a"
	compile_android "armeabi-v7a"
	compile_android "x86"
	compile_android "x86_64"
	compile_linux
	;;
*)
	echo "Sistema operativo objetivo desconocido: $TARGET_OS"
	exit 1
	;;
esac

echo "==================== Compilación completada ====================="
echo "Librerías compiladas y almacenadas en: $COMPILATION_DIR"
