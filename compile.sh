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

# Parche urgente para sdl2.pc (agrega -liconv a Libs en lugar de Libs.private)
find /compiled -name "sdl2.pc" -exec sed -i 's/^Libs: .*/& -liconv/' {} +
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
	local -x LINUX_FFMPEG="/tmp/app/linux/ffmpeg"
	rm -rf "$LINUX_FFMPEG" && mkdir -p "$LINUX_FFMPEG" && cp -r /app/ffmpeg/* "$LINUX_FFMPEG"

	local LIBS_PREFIX="$COMPILATION_DIR/linux_x86_64"
	local -x PKG_CONFIG_PATH="$LIBS_PREFIX/lib/pkgconfig:$LIBS_PREFIX/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"

	cd $LINUX_FFMPEG

	local feature_flags="--enable-iconv --enable-zlib --enable-libxml2 --enable-libsoxr --enable-openssl --enable-libvmaf --enable-fontconfig --enable-libharfbuzz --enable-libfreetype --enable-libfribidi --enable-vulkan --enable-libshaderc --enable-libvorbis --enable-libxcb --enable-xlib --enable-libpulse --enable-gmp --enable-lzma --enable-liblcevc-dec --enable-opencl --enable-amf --enable-libaom --enable-libaribb24 --enable-avisynth --enable-chromaprint --enable-libdav1d --enable-libdavs2 --enable-libdvdread --enable-libdvdnav --disable-libfdk-aac --enable-ffnvcodec --enable-cuda-llvm --enable-frei0r --enable-libgme --enable-libkvazaar --enable-libaribcaption --enable-libass --enable-libbluray --enable-libjxl --enable-libmp3lame --enable-libopus --enable-libplacebo --enable-librist --enable-libssh --enable-libtheora --enable-libvpx --enable-libwebp --enable-libzmq --enable-lv2 --enable-libvpl --enable-openal --enable-liboapv --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-librav1e --enable-librubberband --disable-schannel --enable-sdl2 --enable-libsnappy --enable-libsrt --enable-libsvtav1 --enable-libtwolame --enable-libuavs3d --enable-libdrm --enable-vaapi --enable-libvidstab --enable-libvvenc --disable-whisper --enable-libx264 --enable-libx265 --enable-libxavs2 --enable-libxvid --enable-libzimg --enable-libzvbi"

	./configure \
		--prefix="$LIBS_PREFIX" \
		--pkg-config-flags=--static \
		--enable-gpl \
		--enable-version3 \
		--enable-static --disable-shared \
		--disable-debug \
		--disable-ffplay \
		--disable-doc \
		--extra-cflags="-I$LIBS_PREFIX/include" \
		--extra-ldflags="-static -L$LIBS_PREFIX/lib -Wl,--allow-multiple-definition" \
		--extra-libs="-lstdc++ -lm -lpthread -ldl -latomic" \
		$feature_flags || {
		tail -n 100 ffbuild/config.log
		exit 1
	}

	make -j"$(nproc)"

	mkdir -p /dist/linux-x86_64
	cp ffmpeg /dist/linux-x86_64/ffmpeg
	cp ffprobe /dist/linux-x86_64/ffprobe
}

build_windows() {
	echo "=================================================="
	echo " Compilando Windows (x86_64-mingw32) - Estático"
	echo "=================================================="
	local -x WINDOWS_FFMPEG="/tmp/app/windows/ffmpeg"
	rm -rf "$WINDOWS_FFMPEG" && mkdir -p "$WINDOWS_FFMPEG" && cp -r /app/ffmpeg/* "$WINDOWS_FFMPEG"

	local LIBS_PREFIX="$COMPILATION_DIR/windows_x86_64"
	local WIN_SYSROOT="/mingw64"
	local WIN_PKG_CONFIG_LIBDIR="$WIN_SYSROOT/lib/pkgconfig:$WIN_SYSROOT/share/pkgconfig:$LIBS_PREFIX/lib/pkgconfig"

	local -x CROSS_PREFIX="x86_64-w64-mingw32-"
	local -x PKG_CONFIG_PATH="$WIN_PKG_CONFIG_LIBDIR"
	local -x PKG_CONFIG_LIBDIR="$WIN_PKG_CONFIG_LIBDIR"

	local -x PKG_CONFIG="$LIBS_PREFIX/windows-pkg-config.sh"
	if [ ! -f "$PKG_CONFIG" ]; then
		cat <<'EOF' > "$PKG_CONFIG"
#!/usr/bin/env bash
out=$(/usr/bin/pkg-config "$@")
status=$?
if [ "$status" -ne 0 ]; then
    exit "$status"
fi
printf '%s\n' "$out" | sed -E 's/(^|[[:space:]])-lgcc_s([^[:space:]]*)//g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
EOF
		chmod +x "$PKG_CONFIG"
	fi

	local -x EXTRA_LDFLAGS_COMPAT=""

	cd $WINDOWS_FFMPEG

	local feature_flags="--enable-iconv --enable-zlib --enable-libxml2 --enable-libvmaf --enable-fontconfig --enable-libharfbuzz --enable-libfreetype --enable-libfribidi --enable-vulkan --enable-libshaderc --enable-libvorbis --disable-libxcb --disable-xlib --disable-libpulse --enable-gmp --enable-lzma --enable-liblcevc-dec --enable-opencl --enable-amf --enable-libaom --enable-libaribb24 --enable-avisynth --enable-chromaprint --enable-libdav1d --enable-libdavs2 --enable-libdvdread --enable-libdvdnav --disable-libfdk-aac --enable-ffnvcodec --enable-cuda-llvm --enable-frei0r --enable-libgme --enable-libkvazaar --enable-libaribcaption --enable-libass --enable-libbluray --enable-libjxl --enable-libmp3lame --enable-libopus --enable-libplacebo --enable-librist --enable-libssh --enable-libtheora --enable-libvpx --enable-libwebp --enable-libzmq --enable-lv2 --enable-libvpl --enable-openal --enable-liboapv --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-librav1e --enable-librubberband --enable-schannel --enable-sdl2 --enable-libsnappy --enable-libsoxr --enable-libsrt --enable-libsvtav1 --enable-libtwolame --enable-libuavs3d --disable-libdrm --disable-vaapi --enable-libvidstab --disable-libvvenc --disable-whisper --enable-libx264 --enable-libx265 --enable-libxavs2 --enable-libxvid --enable-libzimg --enable-libzvbi"

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
		--extra-cflags="-static -std=gnu11 -I$LIBS_PREFIX/include -I$WIN_SYSROOT/include -DCHROMAPRINT_NODLL -DKVZ_STATIC_LIB -DLIBTWOLAME_STATIC -DZMQ_STATIC -DAL_LIBTYPE_STATIC -DLIBSSH_STATIC -D_ISOC11_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -DWIN32_LEAN_AND_MEAN -D__USE_MINGW_ANSI_STDIO=1 -D_POSIX_C_SOURCE=200112 -D_XOPEN_SOURCE=600 -DPIC" \
		--extra-ldflags="$EXTRA_LDFLAGS_COMPAT -static -static-libgcc -static-libstdc++ -L$LIBS_PREFIX/lib -L$WIN_SYSROOT/lib -pthread" \
		--extra-libs="-static-libgcc -static-libstdc++ -lgomp -lz -lws2_32 -lcrypt32 -liconv -lgdi32 -lbcrypt -liphlpapi -lmingwex -lstdc++ -lwinpthread -lharfbuzz -lfreetype -lrpcrt4 -lusp10 -lole32 -luuid -lavrt -lwinmm -lcfgmgr32" \
		$feature_flags || {
		tail -n 100 ffbuild/config.log
		exit 1
	}

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
	local -x ANDROID_FFMPEG="/tmp/app/android/$ABI/ffmpeg"
	rm -rf "$ANDROID_FFMPEG" && mkdir -p "$ANDROID_FFMPEG" && cp -r /app/ffmpeg/* "$ANDROID_FFMPEG"
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

	local -x AR="${TOOLCHAIN}/bin/llvm-ar"
	local -x CC="${TOOLCHAIN}/bin/${TARGET_HOST}${API_LEVEL}-clang"
	local -x CXX="${TOOLCHAIN}/bin/${TARGET_HOST}${API_LEVEL}-clang++"
	local -x AS="${CC}"
	local -x ASFLAGS="-c"
	local -x LD="${CC}"
	local -x RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
	local -x STRIP="${TOOLCHAIN}/bin/llvm-strip"

	local PREFIX="$COMPILATION_DIR/android_$ABI"
	local -x PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
	local -x PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

	cd "$ANDROID_FFMPEG"
	make distclean >/dev/null 2>&1 || true

	# Parchear archivos .pc de pkg-config generados por CMake que pueden contener dependencias problemáticas
	find "$PREFIX/lib/pkgconfig" "$PREFIX/lib64/pkgconfig" -name "*.pc" -exec sed -i 's/-l-pthread//g; s/-lpthread//g; s/-l-l:libunwind.a//g; s/-l:libunwind.a//g; s/libunwind.a//g; s/-lc++ //g; s/-lc++$//g' {} + 2>/dev/null || true

	local feature_flags="--enable-iconv --enable-zlib --enable-libxml2 --enable-libvmaf --enable-fontconfig --enable-libharfbuzz --enable-libfreetype --enable-libfribidi --enable-vulkan --enable-libshaderc --enable-libvorbis --enable-gmp --enable-lzma --enable-liblcevc-dec --enable-opencl --enable-amf --enable-libaom --enable-libaribb24 --enable-avisynth --enable-chromaprint --enable-libdav1d --enable-libdavs2 --enable-libdvdread --enable-libdvdnav --disable-libfdk-aac --enable-ffnvcodec --enable-cuda-llvm --enable-frei0r --enable-libgme --enable-libkvazaar --enable-libaribcaption --enable-libass --enable-libbluray --enable-libjxl --enable-libmp3lame --enable-libopus --enable-libplacebo --enable-librist --enable-libssh --enable-libtheora --enable-libvpx --enable-libwebp --enable-libzmq --enable-lv2 --enable-libvpl --enable-openal --enable-liboapv --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-librav1e --enable-librubberband --enable-sdl2 --enable-libsnappy --enable-libsrt --enable-libsvtav1 --enable-libtwolame --enable-libuavs3d --disable-vaapi --enable-libvidstab --enable-libvvenc --disable-whisper --enable-libx264 --enable-libx265 --enable-libxavs2 --enable-libxvid --enable-libzimg --enable-libzvbi --enable-libsoxr --disable-libxcb --disable-xlib --disable-libpulse --disable-libdrm --disable-schannel --enable-mediacodec --enable-jni"

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
		--extra-cflags="-I$PREFIX/include" \
		--extra-ldflags="-L$PREFIX/lib" \
		--extra-libs="-lm -Wl,-Bstatic -lc++_static -lc++abi -lunwind -Wl,-Bdynamic -latomic" \
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
		$feature_flags || {
		tail -n 100 ffbuild/config.log
		exit 1
	}

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
		arm64-v8a | armeabi-v7a | x86 | x86_64) build_android "$TARGET_ARCH" ;;
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
