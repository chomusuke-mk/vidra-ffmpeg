#!/bin/bash
set -euo pipefail

# Configuracion
CONFIG_FILE="/build/config.sh"
FFMPEG_VER="7.1.3"
FFMPEG_EXTRA_VERSION=""
X264_VER="stable"
FFMPEG_LIBS_COMMON=""
FFMPEG_LIBS_LINUX=""
FFMPEG_LIBS_WINDOWS=""
FFMPEG_LIBS_ANDROID=""
ANDROID_ABIS="arm64-v8a"

# Paquetes base reutilizables para todos los SO; solo se descargan (no se compilan).
COMMON_SRC_BUNDLES=(
    "zlib|1.3.1|https://zlib.net/zlib-1.3.1.tar.gz"
    "brotli|1.1.0|https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
    "openssl|3.3.2|https://www.openssl.org/source/openssl-3.3.2.tar.gz"
    "expat|2.6.4|https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.gz"
    "libxml2|2.12.7|https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz"
)

# Default warning suppressions for mingw builds to keep output clean.
MINGW_SUPPRESS_DEFAULT="-Wno-declaration-after-statement -Wno-array-parameter -Wno-deprecated-declarations -Wno-format -Wno-unused-but-set-variable -Wno-unknown-pragmas -Wno-maybe-uninitialized"

SRC_ROOT="/build/sources"

function _fetch_source_bundle {
    local bundle=$1
    IFS="|" read -r name ver url <<<"$bundle"
    local dest_dir="$SRC_ROOT/${name}-${ver}"
    local tmp=/tmp/${name}-${ver}

    if [ -d "$dest_dir" ]; then
        return
    fi

    echo "--- Descargando $name $ver ---"
    curl -L "$url" -o "$tmp"

    case "$url" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmp" -C "$SRC_ROOT"
            ;;
        *.tar.xz|*.txz)
            tar -xJf "$tmp" -C "$SRC_ROOT"
            ;;
        *.zip)
            unzip -q "$tmp" -d "$SRC_ROOT"
            ;;
        *)
            echo "[WARN] Formato desconocido para $url; se mantiene comprimido en $tmp" >&2
            return
            ;;
    esac

    rm -f "$tmp"
}

function load_config {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    if [ -z "${LIBS_COMMON:-}" ]; then
        echo "[ERROR] LIBS_COMMON no definido en $CONFIG_FILE" >&2
        exit 1
    fi

    FFMPEG_VER=${FFMPEG_VERSION:-$FFMPEG_VER}
    FFMPEG_LIBS_COMMON=${LIBS_COMMON}
    FFMPEG_LIBS_LINUX=${LIBS_LINUX:-}
    FFMPEG_LIBS_WINDOWS=${LIBS_WINDOWS:-}
    FFMPEG_LIBS_ANDROID=${LIBS_ANDROID:-}
    ANDROID_ABIS=${ANDROID_ABIS:-$ANDROID_ABIS}
    FFMPEG_EXTRA_VERSION=${EXTRA_VERSION:-$FFMPEG_EXTRA_VERSION}

    # Provide a default set of warning suppressions for mingw unless the user overrides it.
    MINGW_SUPPRESS_WARNINGS=${MINGW_SUPPRESS_WARNINGS:-$MINGW_SUPPRESS_DEFAULT}
}

function ensure_sources {
    load_config
    mkdir -p "$SRC_ROOT"

    if [ ! -d "$SRC_ROOT/x264/.git" ]; then
        echo "--- Descargando x264 ($X264_VER) ---"
        rm -rf "$SRC_ROOT/x264"
        git clone --branch "$X264_VER" --depth 1 https://code.videolan.org/videolan/x264.git "$SRC_ROOT/x264"
    fi

    if [ ! -d "$SRC_ROOT/ffmpeg-$FFMPEG_VER" ]; then
        echo "--- Descargando FFmpeg $FFMPEG_VER ---"
        rm -rf "$SRC_ROOT/ffmpeg-$FFMPEG_VER"
        curl -L "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz" -o /tmp/ffmpeg.tar.xz
        tar -xJf /tmp/ffmpeg.tar.xz -C "$SRC_ROOT"
        rm /tmp/ffmpeg.tar.xz
    fi

    # Prefetch bundles comunes reutilizables entre OS/ABIs para evitar descargas por separado.
    local requested_libs=" $FFMPEG_LIBS_COMMON $FFMPEG_LIBS_LINUX $FFMPEG_LIBS_WINDOWS $FFMPEG_LIBS_ANDROID "
    for bundle in "${COMMON_SRC_BUNDLES[@]}"; do
        IFS="|" read -r name _ url <<<"$bundle"
        if [[ "$requested_libs" != *" $name "* ]]; then
            continue
        fi
        _fetch_source_bundle "$bundle"
    done
}

function build_x264 {
    # Recibe argumentos: $HOST_COMPILER, $PREFIX, $EXTRA_FLAGS
    local HOST=$1
    local PREFIX=$2
    local FLAGS=$3

    # Silence noisy warnings from mingw builds without muting other targets.
    local cflags=${CFLAGS:-}
    if [[ "$HOST" == *mingw* ]]; then
        cflags+=" ${MINGW_SUPPRESS_WARNINGS:-$MINGW_SUPPRESS_DEFAULT} -Wno-alloc-size-larger-than -Wno-unused-function -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast"
    fi

    pushd "$SRC_ROOT/x264" >/dev/null
    CFLAGS="$cflags" ./configure --prefix="$PREFIX" --host="$HOST" --enable-static $FLAGS
    make -j"$(nproc)"
    make install
    popd >/dev/null
}

function collect_target_libs {
    local target=$1
    local libs="$FFMPEG_LIBS_COMMON"

    case "$target" in
        linux)
            libs="$libs $FFMPEG_LIBS_LINUX"
            ;;
        windows)
            libs="$libs $FFMPEG_LIBS_WINDOWS"
            ;;
        android)
            # Para Android habilitamos comunes + específicos (los faltantes se avisan vía pkg-config).
            libs="$libs $FFMPEG_LIBS_ANDROID"
            ;;
    esac

    # TLS backend rules:
    # - schannel is Windows-only; drop it on other platforms.
    # - On Windows, if schannel is present, remove other TLS backends to avoid conflicts.
    if [[ " $libs " == *" schannel "* ]]; then
        local filtered=()
        local tls_conflicts=(openssl gnutls libtls mbedtls)
        for item in $libs; do
            # Drop schannel when target is not Windows
            if [ "$item" = "schannel" ] && [ "$target" != "windows" ]; then
                continue
            fi
            local skip=0
            if [ "$target" = "windows" ] && [ "$item" != "schannel" ]; then
                for conflict in "${tls_conflicts[@]}"; do
                    if [ "$item" = "$conflict" ]; then
                        skip=1
                        break
                    fi
                done
            fi
            [ "$skip" -eq 0 ] && filtered+=("$item")
        done
        libs="${filtered[*]}"
    fi

    echo "$libs" | xargs -n1 | sort -u | xargs
}

function prepare_nvcodec_headers {
    local install_prefix="/usr/local"
    local mingw_prefix="/usr/x86_64-w64-mingw32/mingw64"

    # Prefer installing into the mingw sysroot when building Windows targets.
    if [ -d "$mingw_prefix/include" ]; then
        install_prefix="$mingw_prefix"
    elif [ -d "/usr/x86_64-w64-mingw32/include" ]; then
        install_prefix="/usr/x86_64-w64-mingw32"
    fi

    local header_path="$install_prefix/include/ffnvcodec/nvEncodeAPI.h"

    if [ ! -d "$SRC_ROOT/nv-codec-headers/.git" ]; then
        echo "--- Descargando nv-codec-headers (para NVENC/CUDA) ---"
        rm -rf "$SRC_ROOT/nv-codec-headers"
        git clone --depth 1 https://github.com/FFmpeg/nv-codec-headers "$SRC_ROOT/nv-codec-headers"
    fi

    # Ensure headers are installed where the cross compiler will look for them.
    if [ ! -f "$header_path" ]; then
        pushd "$SRC_ROOT/nv-codec-headers" >/dev/null
        make -j"$(nproc)" >/dev/null
        make install PREFIX="$install_prefix" >/dev/null
        popd >/dev/null
    fi
}

function ffmpeg_feature_flags {
    local target=$1
    local libs=$2
    local flags=""
    local pkg_path="${PKG_CONFIG_PATH:-}"
    local pkg_libdir="${PKG_CONFIG_LIBDIR:-}"

    pkg_exists() {
        PKG_CONFIG_PATH="$pkg_path" PKG_CONFIG_LIBDIR="$pkg_libdir" pkg-config --exists "$1" 2>/dev/null
    }

    add_flag_if_pkg() {
        local flag=$1
        local label=${2:-$flag}
        shift 2 || true
        local candidates=("$label" "$flag" "$@")
        local found=0
        for pkg in "${candidates[@]}"; do
            if pkg_exists "$pkg"; then
                flags+=" $flag"
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "[WARN] ${label} no encontrado; omitiendo" >&2
        fi
    }

    for lib in $libs; do
        case "$lib" in
            x264)
                flags+=" --enable-libx264 --enable-gpl"
                ;;
            libx265)
                add_flag_if_pkg "--enable-libx265" "libx265" x265
                ;;
            libsvtav1)
                add_flag_if_pkg "--enable-libsvtav1" "libsvtav1" SvtAv1Enc svtav1
                ;;
            libdav1d)
                add_flag_if_pkg "--enable-libdav1d" "libdav1d" dav1d
                ;;
            libvpx)
                add_flag_if_pkg "--enable-libvpx" "libvpx" vpx
                ;;
            libwebp)
                add_flag_if_pkg "--enable-libwebp" "libwebp"
                ;;
            libmp3lame)
                add_flag_if_pkg "--enable-libmp3lame" "libmp3lame" lame
                ;;
            libopus|opus)
                add_flag_if_pkg "--enable-libopus" "libopus" opus
                ;;
            libopenjpeg)
                add_flag_if_pkg "--enable-libopenjpeg" "libopenjp2"
                ;;
            zimg|libzimg)
                add_flag_if_pkg "--enable-libzimg" "libzimg" zimg
                ;;
            libsoxr)
                add_flag_if_pkg "--enable-libsoxr" "libsoxr" soxr
                ;;
            libsnappy)
                add_flag_if_pkg "--enable-libsnappy" "libsnappy" snappy
                ;;
            openssl)
                add_flag_if_pkg "--enable-openssl" "openssl" openssl libssl
                ;;
            brotli)
                local cfg_file="$SRC_ROOT/ffmpeg-$FFMPEG_VER/configure"
                if [ -f "$cfg_file" ] && grep -q "enable-brotli" "$cfg_file"; then
                    add_flag_if_pkg "--enable-brotli" "libbrotlienc" libbrotlienc libbrotlidec libbrotlicommon brotli
                fi
                ;;
            libxml2)
                add_flag_if_pkg "--enable-libxml2" "libxml2" libxml-2.0
                ;;
            fontconfig)
                add_flag_if_pkg "--enable-fontconfig" "fontconfig"
                ;;
            harfbuzz|libharfbuzz)
                add_flag_if_pkg "--enable-libharfbuzz" "harfbuzz"
                ;;
            freetype|libfreetype)
                add_flag_if_pkg "--enable-libfreetype" "freetype" freetype2
                ;;
            fribidi|libfribidi)
                add_flag_if_pkg "--enable-libfribidi" "fribidi"
                ;;
            libass)
                add_flag_if_pkg "--enable-libass" "libass"
                ;;
            zlib)
                add_flag_if_pkg "--enable-zlib" "zlib"
                ;;
            libssh)
                add_flag_if_pkg "--enable-libssh" "libssh"
                ;;
            libvpl)
                add_flag_if_pkg "--enable-libvpl" "libvpl" libvpl vpl onevpl oneVPL
                ;;
            nvcodec)
                # Only enable NVENC when the CUDA toolkit is present (nvcc available).
                if command -v nvcc >/dev/null 2>&1; then
                    # Silence header prep stdout to keep feature flag capture clean; errors will still abort.
                    prepare_nvcodec_headers >/dev/null
                    flags+=" --enable-ffnvcodec --enable-nvenc"
                else
                    echo "[WARN] nvcodec requiere nvcc; omitiendo NVENC" >&2
                fi
                ;;
            vaapi)
                if pkg-config --exists libva 2>/dev/null; then
                    flags+=" --enable-vaapi"
                else
                    echo "[WARN] libva no encontrado; omitiendo vaapi" >&2
                fi
                ;;
            dxva2)
                flags+=" --enable-dxva2"
                ;;
            d3d11va)
                flags+=" --enable-d3d11va"
                ;;
            mediacodec)
                flags+=" --enable-mediacodec --enable-jni"
                ;;
            jni)
                flags+=" --enable-jni"
                ;;
            vulkan)
                add_flag_if_pkg "--enable-vulkan" "vulkan"
                ;;
            opencl)
                add_flag_if_pkg "--enable-opencl" "opencl" OpenCL
                ;;
            schannel)
                if [[ "$libs" == *"openssl"* ]]; then
                    echo "[WARN] schannel entra en conflicto con openssl; omitiendo" >&2
                else
                    flags+=" --enable-schannel"
                fi
                ;;
            *)
                echo "[WARN] Libreria desconocida '$lib' en target $target" >&2
                ;;
        esac
    done

    echo "$flags"
}

function ffmpeg_extra_version_flag {
    if [ -n "${FFMPEG_EXTRA_VERSION:-}" ]; then
        echo "--extra-version=${FFMPEG_EXTRA_VERSION}"
    fi
}