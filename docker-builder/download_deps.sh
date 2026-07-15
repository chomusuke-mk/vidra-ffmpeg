#!/bin/bash
set -euo pipefail

DOWNLOADS_DIR="$(realpath "$1")"
mkdir -p "$DOWNLOADS_DIR"

echo "================ Descargando dependencias ==================="

download_if_missing() {
	local name=$1
	local url=$2
	local filename

	# Manejar URLs raras
	case "$url" in
	*".pkg.tar.zst"*) filename="${name}.pkg.tar.zst" ;;
	*"tar.gz"*) filename="${name}.tar.gz" ;;
	*"tar.xz"*) filename="${name}.tar.xz" ;;
	*"tar.bz2"*) filename="${name}.tar.bz2" ;;
	*)
		# Si no coincide con ninguna de las anteriores, cae aquí
		echo "Error: No se pudo determinar el nombre del archivo para $name desde la URL: $url" >&2
		exit 1
		;;
	esac

	local target="$DOWNLOADS_DIR/$filename"

	if [ ! -f "$target" ]; then
		echo "Descargando $name..."
		curl -L --fail --retry 5 --retry-delay 1 "$url" -o "${target}.tmp"
		mv "${target}.tmp" "$target"
	else
		echo "$name ya descargado."
	fi
}
# --- Common/Linux/Windows Libs ---
download_if_missing "zlib" "https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz"
download_if_missing "libssh" "https://gitlab.com/libssh/libssh-mirror/-/archive/libssh-0.12.0/libssh-mirror-libssh-0.12.0.tar.gz"
download_if_missing "brotli" "https://github.com/google/brotli/archive/v1.2.0.tar.gz"
download_if_missing "openssl" "https://github.com/openssl/openssl/releases/download/openssl-3.5.7/openssl-3.5.7.tar.gz"
download_if_missing "expat" "https://github.com/libexpat/libexpat/releases/download/R_2_8_2/expat-2.8.2.tar.gz"
download_if_missing "libxml2" "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz"
download_if_missing "freetype" "https://download.savannah.gnu.org/releases/freetype/freetype-2.14.3.tar.gz"
download_if_missing "fribidi" "https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz"
download_if_missing "harfbuzz" "https://github.com/harfbuzz/harfbuzz/releases/download/14.2.1/harfbuzz-14.2.1.tar.xz"
download_if_missing "libass" "https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.gz"
download_if_missing "dav1d" "https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz"
download_if_missing "libvpx" "https://github.com/webmproject/libvpx/archive/refs/tags/v1.16.0.tar.gz"
download_if_missing "libwebp" "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz"
download_if_missing "openjpeg" "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.4.tar.gz"
download_if_missing "zimg" "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz"
download_if_missing "soxr" "https://downloads.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz"
download_if_missing "fontconfig" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.16.0.tar.xz"
download_if_missing "lame" "https://download.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz"
download_if_missing "opus" "https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz"

download_if_missing "x264" "https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz"
download_if_missing "x265" "https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.2.tar.gz"
download_if_missing "svtav1" "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v4.2.0/SVT-AV1-v4.2.0.tar.gz"
download_if_missing "vulkan-headers" "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "vulkan-loader" "https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "oneVPL" "https://github.com/intel/libvpl/archive/refs/tags/v2.17.0.tar.gz"
download_if_missing "libva" "https://github.com/intel/libva/releases/download/2.24.1/libva-2.24.1.tar.bz2"
download_if_missing "opencl-headers" "https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v2026.05.29.tar.gz"
download_if_missing "opencl-icd-loader" "https://github.com/KhronosGroup/OpenCL-ICD-Loader/archive/refs/tags/v2026.05.29.tar.gz"

# --- Android specific libs ---
download_if_missing "libogg" "https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.gz"
download_if_missing "libvorbis" "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
download_if_missing "twolame" "https://downloads.sourceforge.net/twolame/twolame-0.4.0.tar.gz"
download_if_missing "libpng" "https://download.sourceforge.net/libpng/libpng-1.6.58.tar.gz"
download_if_missing "vid.stab" "https://github.com/georgmartius/vid.stab/archive/refs/tags/v1.1.1.tar.gz"
download_if_missing "srt" "https://github.com/Haivision/srt/archive/refs/tags/v1.5.5.tar.gz"
download_if_missing "libaom" "https://storage.googleapis.com/aom-releases/libaom-3.14.1.tar.gz"

# --- Windows headers ---
download_if_missing "nv-codec-headers" "https://github.com/FFmpeg/nv-codec-headers/releases/download/n13.1.15.0/nv-codec-headers-13.1.15.0.tar.gz"
download_if_missing "amf" "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/releases/download/v1.5.2/AMF-headers-v1.5.2.tar.gz"

# --- Windows MSYS2 precompiled dependencies ---
download_if_missing "mingw-w64-x86_64-bzip2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-bzip2-1.0.8-3-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-brotli" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-brotli-1.2.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-expat" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-expat-2.8.2-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-graphite2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-graphite2-1.3.15-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libffi" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libffi-3.7.1-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-pcre2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-pcre2-10.47-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-gettext" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-gettext-0.22.4-3-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-glib2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-glib2-2.88.2-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libunibreak" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libunibreak-7.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libogg" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libogg-1.3.6-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-zlib" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-zlib-1.3.2-2-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libpng" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libpng-1.6.58-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libiconv" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libiconv-1.19-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-freetype" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-freetype-2.14.3-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-harfbuzz" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-harfbuzz-14.2.1-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-fribidi" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-fribidi-1.0.16-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-fontconfig" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-fontconfig-2.18.2-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libass" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libass-0.17.5-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libsoxr" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libsoxr-0.1.3-5-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-lame" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-lame-3.100-3-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-opus" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-opus-1.6.1-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-dav1d" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-dav1d-1.5.3-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libvpx" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libvpx-1.16.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libwebp" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libwebp-1.6.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-openjpeg2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-openjpeg2-2.5.4-2-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-zimg" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-zimg-3.0.6-3-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-snappy" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-snappy-1.2.2-2-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libssh" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libssh-0.12.0-3-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-x265" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-x265-4.2-2-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-svt-av1" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-svt-av1-4.1.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-openssl" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-openssl-3.6.3-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libxml2" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libxml2-2.15.3-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-onevpl" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-onevpl-2023.4.0-1-any.pkg.tar.zst"
download_if_missing "mingw-w64-x86_64-libx264" "https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-libx264-0.165.r3222.b35605a-2-any.pkg.tar.zst"

echo "================ Dependencias descargadas ==================="
