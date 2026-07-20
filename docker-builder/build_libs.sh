#!/bin/bash
set -euo pipefail

SRC_ROOT="$(realpath "$1")"
COMPILATION_DIR="$(realpath "$2")"
TEMP_DIR="$(realpath "$3")"
TARGET_OS=${4:-"all"}
TARGET_ARCH=${5:-"all"}

API_LEVEL=24
TOOLCHAIN="${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/linux-x86_64"

build_cmake() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with CMake"
	mkdir -p "$dir/build"
	pushd "$dir/build" >/dev/null
	local toolchain_arg=""
	if [ -n "${TOOLCHAIN_FILE:-}" ] && [ -f "$TOOLCHAIN_FILE" ]; then
		toolchain_arg="-DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE"
	fi
	cmake .. -DCMAKE_INSTALL_PREFIX="$prefix" "$toolchain_arg" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF "$@"
	make -j"$(nproc)"
	make install
	popd >/dev/null
}

build_meson() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Meson"
	pushd "$dir" >/dev/null
	local cross_arg=""
	if [ -n "${MESON_CROSS_FILE:-}" ] && [ -f "$MESON_CROSS_FILE" ]; then
		cross_arg="--cross-file=$MESON_CROSS_FILE"
	fi
	meson setup build --prefix="$prefix" "$cross_arg" --libdir="lib" --buildtype=release --default-library=static "$@"
	ninja -C build
	ninja -C build install
	popd >/dev/null
}

build_autotools() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Autotools/Configure"
	pushd "$dir" >/dev/null
	if [ -f "configure.ac" ]; then
		autoreconf -fiv || true
	fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi
	if [ -f bootstrap ]; then ./bootstrap; fi
	if [ -f autogen.sh ]; then ./autogen.sh; fi
	local host_arg=""
	if [ -n "${HOST:-}" ]; then
		host_arg="--host=$HOST"
	elif [ -n "${TARGET_HOST:-}" ]; then
		host_arg="--host=$TARGET_HOST"
	fi
	./configure --prefix="$prefix" "$host_arg" --enable-static --disable-shared --with-pic "$@"
	make -j"$(nproc)"
	make install
	popd >/dev/null
}

build_make() {
	local dir="$1"
	local prefix="$2"
	shift 2
	echo "   -> Building with Make"
	pushd "$dir" >/dev/null
	make -j"$(nproc)" PREFIX="$prefix" "$@"
	make install PREFIX="$prefix" "$@"
	popd >/dev/null
}

build_library() {
	local dir="$1"
	local prefix="$2"
	local name=$(basename "$dir")
	echo "--- Compilando $name ---"

	# Exceptions for specific libraries
	if [ "$name" == "zix" ]; then
		build_meson "$dir" "$prefix" -Dtests=disabled -Dbenchmarks=disabled
		return
	fi
	if [ "$name" == "frei0r" ]; then
		build_cmake "$dir" "$prefix" -DWITHOUT_OPENCV=ON -DWITHOUT_CAIRO=ON -DWITHOUT_GAVL=ON -DWITHOUT_FACERECOGNITION=ON
		return
	fi
	if [ "$name" == "amf" ]; then
		mkdir -p "$prefix/include/AMF"
		cp -r "$dir/AMF/"* "$prefix/include/AMF/" 2>/dev/null || cp -r "$dir/"* "$prefix/include/AMF/"
		return
	fi
	if [ "$name" == "libaribb24" ]; then
		pushd "$dir" >/dev/null
		autoreconf -fiv
		./configure --prefix="$prefix" --enable-static --disable-shared --with-pic
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi
	if [ "$name" == "libopenmpt" ]; then
		pushd "$dir" >/dev/null
		./configure --prefix="$prefix" --enable-static --disable-shared --with-pic --without-mpg123 --disable-openmpt123 --disable-examples --disable-tests
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi
	if [ "$name" == "chromaprint" ]; then
		build_cmake "$dir" "$prefix" -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF
		echo "Libs.private: -lstdc++ -lm" >>"$prefix/lib/pkgconfig/libchromaprint.pc"
		return
	fi
	if [ "$name" == "sdl2" ]; then
		build_cmake "$dir" "$prefix" -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF
		sed -i 's/Libs.private:/Libs.private: -liconv /g' "$prefix/lib/pkgconfig/sdl2.pc"
		return
	fi
	if [ "$name" == "iconv" ]; then
		pushd "$dir" >/dev/null
		./configure --prefix="$prefix" --enable-static --disable-shared --with-pic
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi
	if [ "$name" == "openssl" ]; then
		pushd "$dir" >/dev/null
		./config --prefix="$prefix" no-shared -fPIC
		make -j"$(nproc)"
		make install_sw
		popd >/dev/null
		return
	fi
	if [ "$name" == "libdavs2" ] || [ "$name" == "libxavs2" ]; then
		pushd "$dir/build/linux" >/dev/null
		./configure --prefix="$prefix" --enable-pic --disable-shared --disable-asm
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi
	if [ "$name" == "libbluray" ]; then
		rm -rf "$dir/subprojects/libudfread"
		find "$dir" -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/\bdec_init\b/bluray_dec_init/g' {} +
		find "$dir" -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/\bdir_open_default\b/bluray_dir_open_default/g' {} +
		find "$dir" -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/\bfile_open_default\b/bluray_file_open_default/g' {} +
	fi
	if [ "$name" == "zlib" ] || [ "$name" == "libpng" ]; then
		pushd "$dir" >/dev/null
		./configure --prefix="$prefix" --static
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi

	if [ "$name" == "libjxl" ]; then
		build_cmake "$dir" "$prefix" -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_ENABLE_SKIA=OFF
		# Fix missing C++ standard library in pkg-config files for static builds
		sed -i 's/-ljxl_threads/-ljxl_threads -lstdc++/g' "$prefix/lib/pkgconfig/libjxl_threads.pc"
		sed -i 's/-ljxl /-ljxl -lstdc++ /g' "$prefix/lib/pkgconfig/libjxl.pc"
		sed -i 's/-ljxl_cms /-ljxl_cms -lstdc++ /g' "$prefix/lib/pkgconfig/libjxl_cms.pc" || true
		return
	fi

	if [ "$name" == "libharfbuzz" ]; then
		build_meson "$dir" "$prefix" -Dfreetype=enabled -Dtests=disabled -Ddocs=disabled -Dglib=disabled -Dgobject=disabled
		return
	fi

	if [ "$name" == "liblcevc" ]; then
		build_cmake "$dir" "$prefix"
		# Fix link order in pkg-config file for static builds (C++ stdlib must be at the end)
		sed -i 's/-lstdc++ -lm //g' "$prefix/lib/pkgconfig/lcevc_dec.pc"
		sed -i 's/^Libs:.*/& -lstdc++ -lm/' "$prefix/lib/pkgconfig/lcevc_dec.pc"
		return
	fi

	if [ "$name" == "libvpl" ]; then
		build_cmake "$dir" "$prefix"
		# Fix missing C++ stdlib and math for static builds
		sed -i 's/Libs.private:/Libs.private: -lstdc++ -lm/g' "$prefix/lib/pkgconfig/vpl.pc"
		return
	fi

	if [ "$name" == "libgme" ]; then
		build_cmake "$dir" "$prefix"
		sed -i 's/-lgcc_s//g; s/-lgcc//g; s/-lc //g' "$prefix/lib/pkgconfig/libgme.pc" || true
		return
	fi
	if [ "$name" == "vulkan-loader" ]; then
		sed -i 's/add_library(vulkan SHARED)/add_library(vulkan STATIC)/g' "$dir/loader/CMakeLists.txt"
		sed -i 's/install(TARGETS vulkan EXPORT VulkanLoaderConfig)/install(TARGETS vulkan DESTINATION lib)/g' "$dir/loader/CMakeLists.txt"
		sed -i '/install(EXPORT VulkanLoaderConfig/d' "$dir/loader/CMakeLists.txt"
		build_cmake "$dir" "$prefix"
		return
	fi
	if [ "$name" == "libshaderc" ]; then
		build_cmake "$dir" "$prefix"
		sed -i 's/-lshaderc_shared/-lshaderc_combined/g' "$prefix/lib/pkgconfig/shaderc.pc" || true
		return
	fi
	if [ "$name" == "libsrt" ]; then
		build_cmake "$dir" "$prefix" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON
		sed -i 's/-lgcc_s//g; s/-lgcc//g; s/-lc //g' "$prefix/lib/pkgconfig/srt.pc" || true
		return
	fi
	if [ "$name" == "libkvazaar" ]; then
		build_autotools "$dir" "$prefix"
		# Fix missing math and pthread libraries in pkg-config file for static builds
		sed -i 's/Libs.private:/Libs.private: -lm -lpthread/g' "$prefix/lib/pkgconfig/kvazaar.pc"
		return
	fi
	if [ "$name" == "libx264" ] || [ "$name" == "libx265" ]; then
		# x264 uses configure, x265 uses cmake in source/
		if [ "$name" == "libx264" ]; then
			pushd "$dir" >/dev/null
			./configure --prefix="$prefix" --enable-static --enable-pic --disable-cli
			make -j"$(nproc)"
			make install
			popd >/dev/null
		else
			pushd "$dir/source" >/dev/null
			cmake . -DCMAKE_INSTALL_PREFIX="$prefix" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
			make -j"$(nproc)"
			make install
			sed -i 's/-lgcc_s//g; s/-lc //g' "$prefix/lib/pkgconfig/x265.pc" || true
			popd >/dev/null
		fi
		return
	fi

	if [ "$name" == "lame" ] || [ "$name" == "libtwolame" ]; then
		pushd "$dir" >/dev/null
		if [ ! -f configure ] && [ -f configure.ac ]; then
			autoreconf -fiv
		fi
		./configure --prefix="$prefix" --enable-static --disable-shared --with-pic --disable-decoder
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi

	if [ "$name" == "libpulse" ]; then
		pushd "$dir" >/dev/null
		find . -type f -name meson.build -exec sed -i 's/shared_library(/library(/g' {} +
		meson setup build --prefix="$prefix" --libdir="lib" --buildtype=release --default-library=static -Ddatabase=simple -Dtests=false -Dman=false -Dx11=disabled -Ddoxygen=false -Dc_link_args="-L$prefix/lib -liconv"
		ninja -C build
		ninja -C build install
		popd >/dev/null
		return
	fi

	if [ "$name" == "libvmaf" ]; then
		pushd "$dir/libvmaf" >/dev/null
		meson setup build --prefix="$prefix" --libdir="lib" --buildtype=release --default-library=static
		ninja -C build
		ninja -C build install
		popd >/dev/null
		return
	fi

	if [ "$name" == "libvpx" ] || [ "$name" == "vpx" ]; then
		pushd "$dir" >/dev/null
		./configure --prefix="$prefix" --disable-shared --enable-static --enable-pic --disable-examples --disable-unit-tests --disable-docs
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi

	if [ "$name" == "openal" ]; then
		build_cmake "$dir" "$prefix" -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DCMAKE_EXE_LINKER_FLAGS="-lm"
		return
	fi

	if [ "$name" == "librav1e" ]; then
		cd "$dir"
		cargo cinstall --release --prefix="$prefix" --libdir="lib" --library-type=staticlib
		sed -i 's/-lgcc_s//g; s/-lc //g' "$prefix/lib/pkgconfig/rav1e.pc" || true
		return
	fi

	if [ "$name" == "librubberband" ]; then
		build_meson "$dir" "$prefix"
		sed -i 's/^Libs:.*/& -lstdc++ -lm/' "$prefix/lib/pkgconfig/rubberband.pc"
		return
	fi

	if [ "$name" == "libopenh264" ]; then
		pushd "$dir" >/dev/null
		make -j"$(nproc)" PREFIX="$prefix" install
		sed -i 's/^Libs:.*/& -lstdc++/' "$prefix/lib/pkgconfig/openh264.pc"
		popd >/dev/null
		return
	fi

	if [ "$name" == "libopenmpt" ]; then
		build_autotools "$dir" "$prefix" --disable-openmpt123
		# Fix missing C++ stdlib and math for static builds
		sed -i 's/Libs.private:/Libs.private: -lstdc++ -lm/g' "$prefix/lib/pkgconfig/libopenmpt.pc"
		return
	fi

	if [ "$name" == "libplacebo" ]; then
		build_meson "$dir" "$prefix" -Ddemos=false
		sed -i 's/^Libs:.*/& -lstdc++/' "$prefix/lib/pkgconfig/libplacebo.pc"
		return
	fi

	if [ "$name" == "libsoxr" ]; then
		build_cmake "$dir" "$prefix" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DWITH_OPENMP=OFF
		sed -i 's/^Libs:.*/& -lm/' "$prefix/lib/pkgconfig/soxr.pc"
		return
	fi

	if [ "$name" == "libssh" ]; then
		build_cmake "$dir" "$prefix" -DBUILD_SHARED_LIBS=OFF -DWITH_EXAMPLES=OFF -DWITH_SERVER=OFF -DWITH_GSSAPI=OFF
		sed -i 's/Requires.private:.*/& libcrypto zlib/' "$prefix/lib/pkgconfig/libssh.pc"
		return
	fi

	if [ "$name" == "libxvid" ]; then
		pushd "$dir/build/generic" >/dev/null
		./configure --prefix="$prefix" --disable-shared
		make -j"$(nproc)"
		make install
		popd >/dev/null
		return
	fi

	# Generic Detection
	if [ -f "$dir/CMakeLists.txt" ]; then
		build_cmake "$dir" "$prefix"
	elif [ -f "$dir/meson.build" ]; then
		build_meson "$dir" "$prefix"
	elif [ -f "$dir/configure" ] || [ -f "$dir/autogen.sh" ] || [ -f "$dir/configure.ac" ]; then
		build_autotools "$dir" "$prefix"
	elif [ -f "$dir/Makefile" ]; then
		build_make "$dir" "$prefix"
	else
		echo "Warning: No known build system found for $name"
		exit 1
	fi
}

compile_linux() {
	echo "==================== Compilando librerías - Linux ====================="
	local -x PREFIX="$COMPILATION_DIR/linux_x86_64"
	local -x LINUX_ROOT="$TEMP_DIR/linux_x86_64"
	rm -rf "$LINUX_ROOT" && mkdir -p "$LINUX_ROOT" && cp -r "$SRC_ROOT/"* "$LINUX_ROOT"
	rm -rf "$PREFIX" && mkdir -p "$PREFIX"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x CFLAGS="-fPIC -O3"
	local -x CXXFLAGS="-fPIC -O3"

	# Dependencies that must be built first
	local LIBS="
	libsndfile
	libudfread
	libdvdread
	lv2
	zix
	serd
	sord
	sratom
	lilv
	libogg

	vulkan-headers
	vulkan-loader
	opencl-headers
	opencl-icd-loader
	nv-codec-headers

	iconv
	zlib
	libxml2
	libvmaf
	fontconfig
	libharfbuzz
	libfreetype
	libfribidi
	libshaderc
	libvorbis
	gmp
	lzma
	liblcevc
	amf
	libaom
	libaribb24
	avisynth
	chromaprint
	libdav1d
	libdavs2
	libdvdnav
	frei0r
	libgme
	libkvazaar
	libaribcaption
	libunibreak
	libass
	libbluray
	libjxl
	lame
	libopus
	libplacebo
	librist
	libssh
	libtheora
	libvpx
	libwebp
	libzmq
	libvpl
	openal
	liboapv
	opencore-amr
	libopenh264
	libopenjpeg
	libopenmpt
	librav1e
	librubberband
	sdl2
	libsnappy
	libsrt
	libsvtav1
	libtwolame
	libuavs3d
	libva
	libvidstab
	libvvenc
	libx264
	libx265
	libxavs2
	libxvid
	libzimg
	libzvbi
	libsoxr

	libxcb
	openssl
	xlib
	libpulse
	libdrm
	"
	for lib in $LIBS; do
		if [ -d "$LINUX_ROOT/$lib" ]; then
			build_library "$LINUX_ROOT/$lib" "$PREFIX"
		fi
	done

	echo "Librerias compiladas y almacenadas en: $PREFIX"
	echo "==================== Compilación completada - Linux ====================="
}

compile_windows() {
	echo "==================== Compilando librerías - Windows ====================="
	local -x PREFIX="$COMPILATION_DIR/windows_x86_64"
	local -x WINDOWS_ROOT="$TEMP_DIR/windows_x86_64"
	rm -rf "$WINDOWS_ROOT" && mkdir -p "$WINDOWS_ROOT" && cp -r "$SRC_ROOT/"* "$WINDOWS_ROOT"
	rm -rf "$PREFIX" && mkdir -p "$PREFIX"

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

	# Dependencies that must be built first
	local PRIORITY_LIBS="libudfread dvdread lv2 zix serd sord sratom lilv"
	for lib in $PRIORITY_LIBS; do
		if [ -d "$WINDOWS_ROOT/$lib" ]; then
			build_library "$WINDOWS_ROOT/$lib" "$PREFIX"
		fi
	done

	echo "Archivos de dependencias precompiladas copiados a /mingw64/"
	echo "============ Compilación completada - Windows ====================="
}

compile_android() {
	local ABI="$1"
	echo "==================== Compilando librerías - Android $ABI ====================="
	local -x PREFIX="$COMPILATION_DIR/android_$ABI"
	local -x ANDROID_ROOT="$TEMP_DIR/android_$ABI"
	rm -rf "$ANDROID_ROOT" && mkdir -p "$ANDROID_ROOT" && cp -r "$SRC_ROOT/"* "$ANDROID_ROOT"
	rm -rf "$PREFIX" && mkdir -p "$PREFIX"

	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
	local -x PKG_CONFIG_SYSROOT_DIR="/"

	local TARGET_HOST
	case "$ABI" in
	arm64-v8a) TARGET_HOST="aarch64-linux-android" ;;
	armeabi-v7a) TARGET_HOST="armv7a-linux-androideabi" ;;
	x86) TARGET_HOST="i686-linux-android" ;;
	x86_64) TARGET_HOST="x86_64-linux-android" ;;
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

	# Dependencies that must be built first
	local PRIORITY_LIBS="libudfread dvdread lv2 zix serd sord sratom lilv"
	for lib in $PRIORITY_LIBS; do
		if [ -d "$ANDROID_ROOT/$lib" ]; then
			build_library "$ANDROID_ROOT/$lib" "$PREFIX"
		fi
	done

	# Extra Linux libs to skip
	local EXTRA_LINUX_LIBS="libsndfile openssl libxcb xlib libpulse libdrm"

	for lib_dir in "$ANDROID_ROOT"/*; do
		if [ -d "$lib_dir" ]; then
			local name=$(basename "$lib_dir")
			if [[ ! " $PRIORITY_LIBS " =~ " $name " ]] && [[ ! " $EXTRA_LINUX_LIBS " =~ " $name " ]]; then
				build_library "$lib_dir" "$PREFIX"
			fi
		fi
	done

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
