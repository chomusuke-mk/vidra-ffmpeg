#!/bin/bash
set -euo pipefail

DOWNLOADS_DIR="$(realpath "$1")"
mkdir -p "$DOWNLOADS_DIR"

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

echo "================ Descargando dependencias ==================="

# Common Libs ==============================================================
# Priority libs
download_if_missing "libudfread" "https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz"
download_if_missing "libdvdread" "https://code.videolan.org/videolan/libdvdread/-/archive/7.1.0/libdvdread-7.1.0.tar.gz"
download_if_missing "lv2" "https://lv2plug.in/spec/lv2-1.18.10.tar.xz"
download_if_missing "zix" "https://download.drobilla.net/zix-0.8.2.tar.xz"
download_if_missing "serd" "https://download.drobilla.net/serd-0.32.10.tar.xz"
download_if_missing "sord" "https://download.drobilla.net/sord-0.16.22.tar.xz"
download_if_missing "sratom" "https://download.drobilla.net/sratom-0.6.22.tar.xz"
download_if_missing "lilv" "https://download.drobilla.net/lilv-0.28.0.tar.xz"
download_if_missing "libogg" "https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.gz"
# Headers
download_if_missing "vulkan-headers" "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "vulkan-loader" "https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/vulkan-sdk-1.4.350.1.tar.gz"
download_if_missing "opencl-headers" "https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v2026.05.29.tar.gz"
download_if_missing "opencl-icd-loader" "https://github.com/KhronosGroup/OpenCL-ICD-Loader/archive/refs/tags/v2026.05.29.tar.gz"
download_if_missing "nv-codec-headers" "https://github.com/FFmpeg/nv-codec-headers/releases/download/n13.1.15.0/nv-codec-headers-13.1.15.0.tar.gz"
# Libs
download_if_missing "iconv" "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz"
download_if_missing "zlib" "https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz"
download_if_missing "libpng" "https://downloads.sourceforge.net/project/libpng/libpng16/1.6.43/libpng-1.6.43.tar.gz"
download_if_missing "libxml2" "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz"
download_if_missing "libvmaf" "https://github.com/Netflix/vmaf/archive/refs/tags/v3.2.0.tar.gz"
download_if_missing "expat" "https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.gz"
download_if_missing "fontconfig" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.16.0.tar.xz"
download_if_missing "libva" "https://github.com/intel/libva/archive/refs/tags/2.22.0.tar.gz"
download_if_missing "libharfbuzz" "https://github.com/harfbuzz/harfbuzz/releases/download/14.2.1/harfbuzz-14.2.1.tar.xz"
download_if_missing "libfreetype" "https://download.savannah.gnu.org/releases/freetype/freetype-2.14.3.tar.gz"
download_if_missing "libfribidi" "https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz"
download_if_missing "libshaderc" "https://github.com/google/shaderc/archive/refs/tags/v2026.2.tar.gz"
download_if_missing "libvorbis" "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
download_if_missing "gmp" "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
download_if_missing "lzma" "https://github.com/tukaani-project/xz/releases/download/v5.8.3/xz-5.8.3.tar.gz"
download_if_missing "liblcevc" "https://github.com/v-novaltd/LCEVCdec/archive/refs/tags/4.2.0.tar.gz"
download_if_missing "amf" "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/releases/download/v1.5.2/AMF-headers-v1.5.2.tar.gz"
download_if_missing "libaom" "https://storage.googleapis.com/aom-releases/libaom-3.14.1.tar.gz"
download_if_missing "libaribb24" "https://github.com/nkoriyama/aribb24/archive/refs/tags/v1.0.3.tar.gz"
download_if_missing "avisynth" "https://github.com/AviSynth/AviSynthPlus/archive/refs/tags/v3.7.5.tar.gz"
download_if_missing "fftw" "http://www.fftw.org/fftw-3.3.10.tar.gz"
download_if_missing "chromaprint" "https://github.com/acoustid/chromaprint/releases/download/v1.6.0/chromaprint-1.6.0.tar.gz"
download_if_missing "libdav1d" "https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz"
download_if_missing "libdavs2" "https://github.com/pkuvcl/davs2/archive/refs/tags/1.7.tar.gz"
download_if_missing "libdvdnav" "https://code.videolan.org/videolan/libdvdnav/-/archive/7.0.0/libdvdnav-7.0.0.tar.gz"
download_if_missing "frei0r" "https://github.com/dyne/frei0r/archive/refs/tags/v3.2.1.tar.gz"
download_if_missing "libgme" "https://github.com/libgme/game-music-emu/releases/download/0.6.5/libgme-0.6.5-src.tar.gz"
download_if_missing "libkvazaar" "https://github.com/ultravideo/kvazaar/releases/download/v2.3.2/kvazaar-2.3.2.tar.gz"
download_if_missing "libaribcaption" "https://github.com/xqq/libaribcaption/archive/refs/tags/v1.1.1.tar.gz"
download_if_missing "libunibreak" "https://github.com/adah1972/libunibreak/releases/download/libunibreak_6_1/libunibreak-6.1.tar.gz"
download_if_missing "libass" "https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.gz"
download_if_missing "libbluray" "https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz"
download_if_missing "libjxl" "https://github.com/libjxl/libjxl/archive/refs/tags/v0.12.0.tar.gz"
download_if_missing "lame" "https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz"
download_if_missing "libopus" "https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz"
download_if_missing "fast_float" "https://github.com/fastfloat/fast_float/archive/refs/tags/v6.1.1.tar.gz"
download_if_missing "libplacebo" "https://github.com/haasn/libplacebo/archive/refs/tags/v7.360.1.tar.gz"
download_if_missing "librist" "https://code.videolan.org/rist/librist/-/archive/v0.2.17/librist-v0.2.17.tar.gz"
download_if_missing "libssh" "https://gitlab.com/libssh/libssh-mirror/-/archive/libssh-0.12.0/libssh-mirror-libssh-0.12.0.tar.gz"
download_if_missing "libtheora" "https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.2.0.tar.xz"
download_if_missing "libvpx" "https://github.com/webmproject/libvpx/archive/refs/tags/v1.16.0.tar.gz"
download_if_missing "libwebp" "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz"
download_if_missing "libzmq" "https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz"
download_if_missing "libvpl" "https://github.com/intel/libvpl/archive/refs/tags/v2.17.0.tar.gz"
download_if_missing "openal" "https://github.com/kcat/openal-soft/archive/refs/tags/1.25.2.tar.gz"
download_if_missing "liboapv" "https://github.com/AcademySoftwareFoundation/openapv/archive/refs/tags/v0.3.0.0.tar.gz"
download_if_missing "opencore-amr" "https://downloads.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz"
download_if_missing "libopenh264" "https://github.com/cisco/openh264/archive/refs/tags/v2.6.0.tar.gz"
download_if_missing "libopenjpeg" "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.4.tar.gz"
download_if_missing "libopenmpt" "https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.7+release.autotools.tar.gz"
download_if_missing "librav1e" "https://github.com/xiph/rav1e/archive/refs/tags/v0.8.1.tar.gz"
download_if_missing "librubberband" "https://github.com/breakfastquay/rubberband/archive/refs/tags/v4.0.0.tar.gz"
download_if_missing "sdl2" "https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz"
download_if_missing "libsnappy" "https://github.com/google/snappy/archive/refs/tags/1.2.2.tar.gz"
download_if_missing "libsrt" "https://github.com/Haivision/srt/archive/refs/tags/v1.5.5.tar.gz"
download_if_missing "libsvtav1" "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v4.2.0/SVT-AV1-v4.2.0.tar.gz"
download_if_missing "libtwolame" "https://downloads.sourceforge.net/twolame/twolame-0.4.0.tar.gz"
download_if_missing "libuavs3d" "https://github.com/uavs3/uavs3d/archive/0e20d2c291853f196c68922a264bcd8471d75b68.tar.gz"
download_if_missing "libva" "https://github.com/intel/libva/releases/download/2.24.1/libva-2.24.1.tar.bz2"
download_if_missing "libvidstab" "https://github.com/georgmartius/vid.stab/archive/refs/tags/v1.1.1.tar.gz"
download_if_missing "libvvenc" "https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v1.14.0.tar.gz"
download_if_missing "libx264" "https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz"
download_if_missing "libx265" "https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.2.tar.gz"
download_if_missing "libxavs2" "https://github.com/pkuvcl/xavs2/archive/refs/tags/1.4.tar.gz"
download_if_missing "libxvid" "https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz"
download_if_missing "libzimg" "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz"
download_if_missing "libzvbi" "https://github.com/zapping-vbi/zvbi/archive/refs/tags/v0.2.44.tar.gz"
download_if_missing "libsoxr" "https://downloads.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz"

# Extra Linux Libs =========================================================
# Priority libs
download_if_missing "libsndfile" "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz"
# Libs
download_if_missing "libxcb" "https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.16.1/libxcb-libxcb-1.16.1.tar.gz"
download_if_missing "openssl" "https://github.com/openssl/openssl/releases/download/openssl-3.5.7/openssl-3.5.7.tar.gz"
download_if_missing "xlib" "https://gitlab.freedesktop.org/xorg/lib/libx11/-/archive/libX11-1.8.13/libx11-libX11-1.8.13.tar.gz"
download_if_missing "libpulse" "https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/archive/v17.0/pulseaudio-v17.0.tar.gz"
download_if_missing "libdrm" "https://gitlab.freedesktop.org/mesa/libdrm/-/archive/libdrm-2.4.134/libdrm-libdrm-2.4.134.tar.gz"

echo "================ Dependencias descargadas ==================="
