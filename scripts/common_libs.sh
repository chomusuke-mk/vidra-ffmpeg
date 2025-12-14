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
FFMPEG_LIBS_COMMON_EXTENDED=""
FFMPEG_LIBS_LINUX_EXTENDED=""
FFMPEG_LIBS_WINDOWS_EXTENDED=""
FFMPEG_LIBS_ANDROID_EXTENDED=""
FFMPEG_BUILDS_LIST="standard"
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
# By default leave empty; set MINGW_SUPPRESS_WARNINGS via Dockerfile/ENV if desired.
MINGW_SUPPRESS_DEFAULT=""

SRC_ROOT="/build/sources"

# SVT-AV1 (libsvtav1): Ubuntu 24.04 puede no proveer la librería/pc, solo headers.
# El repo canónico está en GitLab; el de GitHub es solo un stub.
SVTAV1_REF=${SVTAV1_REF:-v2.3.0}

# Vulkan: FFmpeg 8.x requiere vulkan >= 1.3.277. Ubuntu 24.04 trae 1.3.275,
# así que para habilitarlo instalamos un loader+headers más nuevos en el PREFIX.
VULKAN_SDK_REF=${VULKAN_SDK_REF:-vulkan-sdk-1.3.280.0}

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
    FFMPEG_LIBS_COMMON_EXTENDED=${LIBS_COMMON_EXTENDED:-}
    FFMPEG_LIBS_LINUX_EXTENDED=${LIBS_LINUX_EXTENDED:-}
    FFMPEG_LIBS_WINDOWS_EXTENDED=${LIBS_WINDOWS_EXTENDED:-}
    FFMPEG_LIBS_ANDROID_EXTENDED=${LIBS_ANDROID_EXTENDED:-}
    ANDROID_ABIS=${ANDROID_ABIS:-$ANDROID_ABIS}
    FFMPEG_EXTRA_VERSION=${EXTRA_VERSION:-$FFMPEG_EXTRA_VERSION}
    FFMPEG_BUILDS_LIST=${FFMPEG_BUILDS:-$FFMPEG_BUILDS_LIST}
    if [ -z "$FFMPEG_BUILDS_LIST" ]; then
        FFMPEG_BUILDS_LIST="standard"
    fi

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

    local ffmpeg_dir="$SRC_ROOT/ffmpeg-$FFMPEG_VER"
    # If the directory exists but lacks configure (corrupt/partial download), refresh it.
    if [ -d "$ffmpeg_dir" ] && [ ! -f "$ffmpeg_dir/configure" ]; then
        echo "[WARN] FFmpeg $FFMPEG_VER incompleto; re-descargando..." >&2
        rm -rf "$ffmpeg_dir"
    fi

    if [ ! -d "$ffmpeg_dir" ]; then
        echo "--- Descargando FFmpeg $FFMPEG_VER ---"
        rm -rf "$ffmpeg_dir"
        curl -L "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz" -o /tmp/ffmpeg.tar.xz
        tar -xJf /tmp/ffmpeg.tar.xz -C "$SRC_ROOT"
        rm /tmp/ffmpeg.tar.xz
    fi

    # Prefetch bundles comunes reutilizables entre OS/ABIs para evitar descargas por separado.
    local requested_libs=" $FFMPEG_LIBS_COMMON $FFMPEG_LIBS_LINUX $FFMPEG_LIBS_WINDOWS $FFMPEG_LIBS_ANDROID $FFMPEG_LIBS_COMMON_EXTENDED $FFMPEG_LIBS_LINUX_EXTENDED $FFMPEG_LIBS_WINDOWS_EXTENDED $FFMPEG_LIBS_ANDROID_EXTENDED "
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
        # All warning suppressions come from MINGW_SUPPRESS_WARNINGS; Dockerfile sets the defaults.
        cflags+=" ${MINGW_SUPPRESS_WARNINGS:-$MINGW_SUPPRESS_DEFAULT}"
    else
        # Upstream x264 trips aggressive gcc warnings when building static; keep the build clean without touching sources.
        cflags+=" -Wno-alloc-size-larger-than -Wno-dangling-pointer -Wno-array-bounds -Wno-unused-function"
    fi

    pushd "$SRC_ROOT/x264" >/dev/null
    CFLAGS="$cflags" ./configure --prefix="$PREFIX" --host="$HOST" --enable-static $FLAGS
    make -j"$(nproc)"
    make install
    popd >/dev/null
}

function build_svtav1 {
    # Recibe argumentos: $PREFIX
    local PREFIX=$1

    # Skip if already installed.
    if [ -f "$PREFIX/lib/libSvtAv1Enc.a" ] || [ -f "$PREFIX/lib64/libSvtAv1Enc.a" ]; then
        return
    fi

    # Ensure we have the real upstream checkout (GitHub mirror can be a stub).
    if [ -d "$SRC_ROOT/svt-av1/.git" ] && [ ! -f "$SRC_ROOT/svt-av1/CMakeLists.txt" ]; then
        rm -rf "$SRC_ROOT/svt-av1"
    fi

    if [ ! -d "$SRC_ROOT/svt-av1/.git" ]; then
        echo "--- Descargando SVT-AV1 ($SVTAV1_REF) ---"
        rm -rf "$SRC_ROOT/svt-av1"
        git clone --depth 1 --branch "$SVTAV1_REF" https://gitlab.com/AOMediaCodec/SVT-AV1.git "$SRC_ROOT/svt-av1"
    fi

    echo "--- Compilando SVT-AV1 ---"
    pushd "$SRC_ROOT/svt-av1" >/dev/null
    rm -rf build
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build build -j"$(nproc)"
    cmake --install build

    # FFmpeg (configure) no siempre utiliza Libs.private al testear, pero como
    # instalamos libSvtAv1Enc.a (estático) necesitamos exponer deps como -lm y -lpthread
    # en Libs para que el test de enlace y el link final funcionen.
    local upstream_pc=""
    if [ -f "$PREFIX/lib/pkgconfig/SvtAv1Enc.pc" ]; then
        upstream_pc="$PREFIX/lib/pkgconfig/SvtAv1Enc.pc"
    elif [ -f "$PREFIX/lib64/pkgconfig/SvtAv1Enc.pc" ]; then
        upstream_pc="$PREFIX/lib64/pkgconfig/SvtAv1Enc.pc"
    fi

    if [ -n "$upstream_pc" ]; then
        if ! grep -qE '^Libs:.*(^|[[:space:]])-lm([[:space:]]|$)' "$upstream_pc"; then
            sed -i 's/^Libs:\(.*\)$/Libs:\1 -lm/' "$upstream_pc"
        fi
        if ! grep -qE '^Libs:.*(^|[[:space:]])-lpthread([[:space:]]|$)' "$upstream_pc"; then
            sed -i 's/^Libs:\(.*\)$/Libs:\1 -lpthread/' "$upstream_pc"
        fi
    fi

    # Algunos empaquetados no instalan .pc; genera uno mínimo si falta.
    local pcdir="$PREFIX/lib/pkgconfig"
    mkdir -p "$pcdir"
    if [ ! -f "$pcdir/SvtAv1Enc.pc" ]; then
        local ver="0"
        ver=$(git rev-parse --short HEAD 2>/dev/null || echo 0)
        cat >"$pcdir/SvtAv1Enc.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: SvtAv1Enc
Description: SVT-AV1 encoder
Version: $ver
Libs: -L\${libdir} -lSvtAv1Enc -lm -lpthread
Cflags: -I\${includedir}/svt-av1
EOF
    fi
    popd >/dev/null
}

function build_vulkan {
    # Recibe argumentos: $PREFIX
    local PREFIX=$1

    # Si ya existe una versión suficiente (system o PREFIX), no hagas nada.
    local pkg_path="${PKG_CONFIG_PATH:-}"
    if PKG_CONFIG_PATH="$pkg_path" pkg-config --exists "vulkan >= 1.3.277" 2>/dev/null; then
        return
    fi

    echo "--- Compilando Vulkan (headers+loader) $VULKAN_SDK_REF ---"

    # Vulkan-Headers
    if [ ! -d "$SRC_ROOT/vulkan-headers/.git" ]; then
        rm -rf "$SRC_ROOT/vulkan-headers"
        git clone --depth 1 --branch "$VULKAN_SDK_REF" https://github.com/KhronosGroup/Vulkan-Headers.git "$SRC_ROOT/vulkan-headers"
    fi

    pushd "$SRC_ROOT/vulkan-headers" >/dev/null
    rm -rf build
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    cmake --install build
    popd >/dev/null

    # Vulkan-Loader
    if [ ! -d "$SRC_ROOT/vulkan-loader/.git" ]; then
        rm -rf "$SRC_ROOT/vulkan-loader"
        git clone --depth 1 --branch "$VULKAN_SDK_REF" --recursive https://github.com/KhronosGroup/Vulkan-Loader.git "$SRC_ROOT/vulkan-loader"
    fi

    pushd "$SRC_ROOT/vulkan-loader" >/dev/null
    rm -rf build
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_WSI_XCB_SUPPORT=OFF \
        -DBUILD_WSI_XLIB_SUPPORT=OFF \
        -DBUILD_WSI_WAYLAND_SUPPORT=OFF \
        -DBUILD_WSI_DIRECTFB_SUPPORT=OFF \
        -DBUILD_TESTS=OFF \
        -DCMAKE_PREFIX_PATH="$PREFIX"
    cmake --build build -j"$(nproc)"
    cmake --install build
    popd >/dev/null
}

function collect_target_libs {
    local target=$1
    local variant=${2:-standard}
    local libs="$FFMPEG_LIBS_COMMON"
    local extended="$FFMPEG_LIBS_COMMON_EXTENDED"

    case "$variant" in
        standard|full) ;;
        *)
            echo "[WARN] Variante desconocida '$variant'; usando 'standard'" >&2
            variant="standard"
            ;;
    esac

    case "$target" in
        linux)
            libs="$libs $FFMPEG_LIBS_LINUX"
            [ "$variant" = "full" ] && extended="$extended $FFMPEG_LIBS_LINUX_EXTENDED"
            ;;
        windows)
            libs="$libs $FFMPEG_LIBS_WINDOWS"
            [ "$variant" = "full" ] && extended="$extended $FFMPEG_LIBS_WINDOWS_EXTENDED"
            ;;
        android)
            # Para Android habilitamos comunes + específicos (los faltantes se avisan vía pkg-config).
            libs="$libs $FFMPEG_LIBS_ANDROID"
            [ "$variant" = "full" ] && extended="$extended $FFMPEG_LIBS_ANDROID_EXTENDED"
            ;;
    esac

    if [ "$variant" = "full" ]; then
        libs="$libs $extended"
    fi

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
    # Opcional: fuerza el prefix (p.ej. /usr/local) para builds Linux.
    local install_prefix="${1:-}"
    local mingw_prefix="/usr/x86_64-w64-mingw32/mingw64"

    if [ -z "$install_prefix" ]; then
        install_prefix="/usr/local"

        # Prefer installing into the mingw sysroot when building Windows targets.
        if [ -d "$mingw_prefix/include" ]; then
            install_prefix="$mingw_prefix"
        elif [ -d "/usr/x86_64-w64-mingw32/include" ]; then
            install_prefix="/usr/x86_64-w64-mingw32"
        fi
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
    local want_static=0

    if [[ " ${LDFLAGS:-} ${FFMPEG_LDFLAGS:-} " == *" -static "* ]]; then
        want_static=1
    fi

    pkg_exists() {
        # IMPORTANT: Do not set PKG_CONFIG_LIBDIR to an empty string.
        # If PKG_CONFIG_LIBDIR is set (even empty), pkg-config treats it as an override and may ignore
        # its built-in default search paths (e.g. /usr/lib/x86_64-linux-gnu/pkgconfig), making every
        # system dependency look "missing".
        if [ -n "$pkg_libdir" ]; then
            PKG_CONFIG_PATH="$pkg_path" PKG_CONFIG_LIBDIR="$pkg_libdir" pkg-config --exists "$1" 2>/dev/null
        else
            PKG_CONFIG_PATH="$pkg_path" pkg-config --exists "$1" 2>/dev/null
        fi
    }

    pkg_static_ok() {
        local pkg_expr=$1
        # pkg-config permite expresiones tipo: "name >= 1.2.3". Para consultas de variables/libs
        # necesitamos el nombre base del paquete.
        local pkg=${pkg_expr%% *}
        [ "$want_static" -eq 0 ] && return 0

        # For fully static builds, only rely on libraries we built/installed into PREFIX.
        # Distro-provided .pc files frequently omit private deps needed for static linking.
        local pcfiledir=""
        pcfiledir=$(pkg-config --variable=pcfiledir "$pkg" 2>/dev/null || true)
        if [ -n "${PREFIX:-}" ] && [ -n "$pcfiledir" ]; then
            case "$pcfiledir" in
                "$PREFIX"/*) ;;
                *) return 1 ;;
            esac
        else
            # If we can't identify where the .pc comes from, be conservative.
            return 1
        fi

        # Toolchain/system libs that may not have a matching lib*.a in the same libdir.
        local allow_missing=(c gcc_s m pthread dl rt resolv util stdc++ atomic)

        local libdirs=()
        local pc_libdir=""
        pc_libdir=$(pkg-config --variable=libdir "$pkg" 2>/dev/null || true)
        [ -n "$pc_libdir" ] && libdirs+=("$pc_libdir")

        while IFS= read -r token; do
            case "$token" in
                -L*) libdirs+=("${token#-L}") ;;
            esac
        done < <(pkg-config --static --libs "$pkg" 2>/dev/null | tr ' ' '\n')

        # Dedup
        if [ "${#libdirs[@]}" -gt 0 ]; then
            local dedup=()
            local seen=""
            for d in "${libdirs[@]}"; do
                [[ ":$seen:" == *":$d:"* ]] && continue
                seen+="$d:"
                dedup+=("$d")
            done
            libdirs=("${dedup[@]}")
        fi

        [ "${#libdirs[@]}" -eq 0 ] && return 1

        while IFS= read -r libflag; do
            local name=${libflag#-l}
            local allowed=0
            for a in "${allow_missing[@]}"; do
                if [ "$name" = "$a" ]; then
                    allowed=1
                    break
                fi
            done
            [ "$allowed" -eq 1 ] && continue

            local found=0
            for d in "${libdirs[@]}"; do
                if [ -f "$d/lib${name}.a" ]; then
                    found=1
                    break
                fi
            done
            [ "$found" -eq 1 ] || return 1
        done < <(pkg-config --static --libs-only-l "$pkg" 2>/dev/null | tr ' ' '\n')

        return 0
    }

    pkg_usable() {
        local pkg=$1
        pkg_exists "$pkg" || return 1
        pkg_static_ok "$pkg" || return 1
        return 0
    }

    add_flag_if_pkg() {
        local flag=$1
        local label=${2:-$flag}
        shift 2 || true
        local candidates=("$label" "$flag" "$@")
        local found=0
        local any_exists=0
        local any_nonstatic=0

        for pkg in "${candidates[@]}"; do
            if pkg_exists "$pkg"; then
                any_exists=1
                if pkg_static_ok "$pkg"; then
                    flags+=" $flag"
                    found=1
                    break
                else
                    any_nonstatic=1
                fi
            fi
        done

        if [ "$found" -eq 0 ]; then
            if [ "$want_static" -eq 1 ] && [ "$any_nonstatic" -eq 1 ]; then
                echo "[INFO] ${label} omitido en build estático (no linkeable estáticamente)" >&2
            elif [ "$any_exists" -eq 1 ]; then
                echo "[WARN] ${label} detectado pero no usable; omitiendo" >&2
            else
                echo "[WARN] ${label} no encontrado; omitiendo" >&2
            fi
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
                # FFmpeg requiere SvtAv1Enc >= 0.9.0; valida versión para evitar que configure falle.
                add_flag_if_pkg "--enable-libsvtav1" "libsvtav1" "SvtAv1Enc >= 0.9.0" SvtAv1Enc svtav1
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
                # Linux: el usuario pidió compilar con nvcodec por defecto cuando está solicitado en la lista de libs.
                # Otros targets: mantener opt-in para evitar builds sorpresa.
                if [ -n "${FFMPEG_DISABLE_NVENC:-}" ]; then
                    echo "[INFO] nvcodec deshabilitado por FFMPEG_DISABLE_NVENC=1" >&2
                elif [ "$target" = "linux" ]; then
                    prepare_nvcodec_headers "/usr/local" >/dev/null
                    flags+=" --enable-ffnvcodec --enable-nvenc"
                else
                    if [ -n "${FFMPEG_ALLOW_NVENC:-}" ]; then
                        prepare_nvcodec_headers >/dev/null
                        flags+=" --enable-ffnvcodec --enable-nvenc"
                    else
                        echo "[INFO] nvcodec omitido (set FFMPEG_ALLOW_NVENC=1 para habilitarlo)" >&2
                    fi
                fi
                ;;
            vaapi)
                # VAAPI suele no ser enlazable de forma 100% estática con paquetes de distro.
                # Si estamos forzando -static, evita romper configure a menos que exista libva.a.
                if [[ " ${LDFLAGS:-} ${FFMPEG_LDFLAGS:-} " == *" -static "* ]]; then
                    local va_libdir=""
                    va_libdir=$(pkg-config --variable=libdir libva 2>/dev/null || true)
                    if [ -n "$va_libdir" ] && [ -f "$va_libdir/libva.a" ]; then
                        flags+=" --enable-vaapi"
                    else
                        echo "[WARN] vaapi omitido en build estático (libva.a no disponible)" >&2
                    fi
                else
                    if pkg_exists libva; then
                        flags+=" --enable-vaapi"
                    else
                        echo "[WARN] libva no encontrado; omitiendo vaapi" >&2
                    fi
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
                # FFmpeg 8.0.1 requiere vulkan >= 1.3.277 (VK_HEADER_VERSION >= 277).
                # Ubuntu 24.04 trae 1.3.275, por lo que habilitarlo rompe configure.
                if pkg_usable "vulkan >= 1.3.277"; then
                    flags+=" --enable-vulkan"
                else
                    echo "[WARN] vulkan >= 1.3.277 no encontrado; omitiendo" >&2
                fi
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
    local variant=${1:-}
    local extra=${FFMPEG_EXTRA_VERSION:-}

    if [ "$variant" = "full" ]; then
        if [ -n "$extra" ]; then
            echo "--extra-version=full-$extra"
        else
            echo "--extra-version=full"
        fi
    elif [ -n "$extra" ]; then
        echo "--extra-version=${extra}"
    fi
}

function version_dir_for_variant {
    local variant=${1:-standard}
    if [ "$variant" = "full" ]; then
        echo "${FFMPEG_VER}-full"
    else
        echo "${FFMPEG_VER}"
    fi
}