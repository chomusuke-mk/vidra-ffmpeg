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

# --- Common Libs ---
download_if_missing "iconv" "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz"
download_if_missing "zlib" "https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz"
download_if_missing "libxml2" "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz"
download_if_missing "libvmaf" "https://github.com/Netflix/vmaf/archive/refs/tags/v3.2.0.tar.gz"
download_if_missing "fontconfig" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.16.0.tar.xz"
download_if_missing "harfbuzz" "https://github.com/harfbuzz/harfbuzz/releases/download/14.2.1/harfbuzz-14.2.1.tar.xz"
download_if_missing "freetype" "https://download.savannah.gnu.org/releases/freetype/freetype-2.14.3.tar.gz"
download_if_missing "fribidi" "https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz"
download_if_missing "vulkan-headers" "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "vulkan-loader" "https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "shaderc" "https://github.com/google/shaderc/archive/refs/tags/v2026.2.tar.gz"
download_if_missing "libvorbis" "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
download_if_missing "gmp" "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
download_if_missing "lzma" "https://github.com/tukaani-project/xz/releases/download/v5.8.3/xz-5.8.3.tar.gz"
download_if_missing "liblcevc" "https://github.com/v-novaltd/LCEVCdec/archive/refs/tags/4.2.0.tar.gz"
download_if_missing "opencl-headers" "https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v2026.05.29.tar.gz"
download_if_missing "opencl-icd-loader" "https://github.com/KhronosGroup/OpenCL-ICD-Loader/archive/refs/tags/v2026.05.29.tar.gz"
download_if_missing "amf" "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/releases/download/v1.5.2/AMF-headers-v1.5.2.tar.gz"
download_if_missing "libaom" "https://storage.googleapis.com/aom-releases/libaom-3.14.1.tar.gz"
download_if_missing "aribb24" "https://github.com/nkoriyama/aribb24/archive/refs/tags/v1.0.3.tar.gz"
download_if_missing "avisynth" "https://github.com/AviSynth/AviSynthPlus/archive/refs/tags/v3.7.5.tar.gz"
download_if_missing "chromaprint" "https://github.com/acoustid/chromaprint/releases/download/v1.6.0/chromaprint-1.6.0.tar.gz"
download_if_missing "dav1d" "https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz"
download_if_missing "davs2" "https://github.com/pkuvcl/davs2/archive/refs/tags/1.7.tar.gz"
download_if_missing "dvdread" "https://code.videolan.org/videolan/libdvdread/-/archive/7.1.0/libdvdread-7.1.0.tar.gz"
download_if_missing "dvdnav" "https://code.videolan.org/videolan/libdvdnav/-/archive/7.0.0/libdvdnav-7.0.0.tar.gz"
download_if_missing "nv-codec-headers" "https://github.com/FFmpeg/nv-codec-headers/releases/download/n13.1.15.0/nv-codec-headers-13.1.15.0.tar.gz"
download_if_missing "frei0r" "https://github.com/dyne/frei0r/archive/refs/tags/v3.2.1.tar.gz"
download_if_missing "gme" "https://github.com/libgme/game-music-emu/releases/download/0.6.5/libgme-0.6.5-src.tar.gz"
download_if_missing "kvazaar" "https://github.com/ultravideo/kvazaar/releases/download/v2.3.2/kvazaar-2.3.2.tar.gz"
download_if_missing "libaribbcaption" "https://github.com/xqq/libaribcaption/archive/refs/tags/v1.1.1.tar.gz"
download_if_missing "libass" "https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.gz"
download_if_missing "libbluray" "https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz"
download_if_missing "libjxl" "https://github.com/libjxl/libjxl/archive/refs/tags/v0.12.0.tar.gz"
download_if_missing "libmp3lame" "https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz"
download_if_missing "opus" "https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz"
download_if_missing "placebo" "https://github.com/haasn/libplacebo/archive/refs/tags/v7.360.1.tar.gz"
download_if_missing "rist" "https://code.videolan.org/rist/librist/-/archive/v0.2.17/librist-v0.2.17.tar.gz"
download_if_missing "libssh" "https://gitlab.com/libssh/libssh-mirror/-/archive/libssh-0.12.0/libssh-mirror-libssh-0.12.0.tar.gz"
download_if_missing "theora" "https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.2.0.tar.xz"
download_if_missing "libvpx" "https://github.com/webmproject/libvpx/archive/refs/tags/v1.16.0.tar.gz"
download_if_missing "libwebp" "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz"
download_if_missing "libzmq" "https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz"
download_if_missing "lv2" "https://lv2plug.in/spec/lv2-1.18.10.tar.xz"
download_if_missing "libvpl" "https://github.com/intel/libvpl/archive/refs/tags/v2.17.0.tar.gz"
download_if_missing "openal" "https://github.com/kcat/openal-soft/archive/refs/tags/1.25.2.tar.gz"
download_if_missing "liboapv" "https://github.com/AcademySoftwareFoundation/openapv/archive/refs/tags/v0.3.0.0.tar.gz"
download_if_missing "libopencore-amrnb" "https://downloads.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz"
download_if_missing "openh264" "https://github.com/cisco/openh264/archive/refs/tags/v2.6.0.tar.gz"
download_if_missing "openjpeg" "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.4.tar.gz"
download_if_missing "openmpt" "https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.7+release.autotools.tar.gz"
download_if_missing "rav1e" "https://github.com/xiph/rav1e/archive/refs/tags/v0.8.1.tar.gz"
download_if_missing "rubberband" "https://github.com/breakfastquay/rubberband/archive/refs/tags/v4.0.0.tar.gz"
download_if_missing "sdl2" "https://github.com/libsdl-org/SDL/releases/download/release-3.4.12/SDL3-3.4.12.tar.gz"
download_if_missing "snappy" "https://github.com/google/snappy/archive/refs/tags/1.2.2.tar.gz"
download_if_missing "srt" "https://github.com/Haivision/srt/archive/refs/tags/v1.5.5.tar.gz"
download_if_missing "svtav1" "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v4.2.0/SVT-AV1-v4.2.0.tar.gz"
download_if_missing "twolame" "https://downloads.sourceforge.net/twolame/twolame-0.4.0.tar.gz"
download_if_missing "uavs3d" "https://github.com/uavs3/uavs3d/archive/refs/tags/1.0.tar.gz"
download_if_missing "vid.stab" "https://github.com/georgmartius/vid.stab/archive/refs/tags/v1.1.1.tar.gz"
download_if_missing "vvenc" "https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v1.14.0.tar.gz"
download_if_missing "x264" "https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz"
download_if_missing "x265" "https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.2.tar.gz"
download_if_missing "xavs2" "https://github.com/pkuvcl/xavs2/archive/refs/tags/1.4.tar.gz"
download_if_missing "xvid" "https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz"
download_if_missing "zimg" "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz"
download_if_missing "zvbi" "https://github.com/zapping-vbi/zvbi/archive/refs/tags/v0.2.44.tar.gz"
download_if_missing "soxr" "https://downloads.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz"


# --- Extra Linux Libs ---
download_if_missing "openssl" "https://github.com/openssl/openssl/releases/download/openssl-3.5.7/openssl-3.5.7.tar.gz"
download_if_missing "libxcb" "https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.16.1/libxcb-libxcb-1.16.1.tar.gz"
download_if_missing "xlib" "https://gitlab.freedesktop.org/xorg/lib/libx11/-/archive/libX11-1.8.13/libx11-libX11-1.8.13.tar.gz"
download_if_missing "libpulse" "https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/archive/v17.0/pulseaudio-v17.0.tar.gz"
download_if_missing "libdrm" "https://gitlab.freedesktop.org/mesa/libdrm/-/archive/libdrm-2.4.134/libdrm-libdrm-2.4.134.tar.gz"


echo "================ Dependencias descargadas ==================="
