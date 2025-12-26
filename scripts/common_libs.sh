#!/bin/bash
set -euo pipefail

# Configuracion
CONFIG_FILE="/build/config.sh"
FFMPEG_VER="7.1.3"
FFMPEG_EXTRA_VERSION=""
X264_VER="stable"
X265_REF=${X265_REF:-Release_3.5}
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
VPL_REF=${VPL_REF:-v2023.3.1}
LIBVA_REF=${LIBVA_REF:-2.21.0}
OPENCL_LOADER_REF=${OPENCL_LOADER_REF:-v2023.12.14}

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

    fetch_src_if_missing() {
        local dest=$1
        local url=$2

        if [ -d "$dest" ]; then
            return
        fi

        echo "--- Descargando $(basename "$dest") ---"
        rm -rf "$dest"

        local tmp
        tmp=$(mktemp /tmp/src.XXXXXX)
        curl -L "$url" -o "$tmp"

        case "$url" in
            *.tar.gz|*.tgz)
                tar -xzf "$tmp" -C "$SRC_ROOT"
                ;;
            *.tar.xz|*.txz)
                tar -xJf "$tmp" -C "$SRC_ROOT"
                ;;
            *.tar.bz2|*.tbz2)
                tar -xjf "$tmp" -C "$SRC_ROOT"
                ;;
            *)
                echo "[WARN] Formato desconocido para $url; guardado en $tmp" >&2
                return
                ;;
        esac

        rm -f "$tmp"
    }

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

    # Fetch oneVPL if requested
    if [[ "$requested_libs" == *" libvpl "* ]]; then
        local vpl_dir="$SRC_ROOT/oneVPL"
        if [ ! -d "$vpl_dir/.git" ]; then
            echo "--- Descargando oneVPL ($VPL_REF) ---"
            rm -rf "$vpl_dir"
            git clone --depth 1 --branch "$VPL_REF" https://github.com/intel/oneVPL.git "$vpl_dir"
        fi
    fi

    # Fetch libva if requested
    if [[ "$requested_libs" == *" vaapi "* ]]; then
        local va_dir="$SRC_ROOT/libva"
        if [ ! -d "$va_dir/.git" ]; then
            echo "--- Descargando libva ($LIBVA_REF) ---"
            rm -rf "$va_dir"
            git clone --depth 1 --branch "$LIBVA_REF" https://github.com/intel/libva.git "$va_dir"
        fi
    fi

    # Fetch OpenCL headers + loader if requested
    if [[ "$requested_libs" == *" opencl "* ]]; then
        local ocl_headers="$SRC_ROOT/OpenCL-Headers"
        local ocl_loader="$SRC_ROOT/OpenCL-ICD-Loader"
        if [ ! -d "$ocl_headers/.git" ]; then
            echo "--- Descargando OpenCL-Headers (main) ---"
            rm -rf "$ocl_headers"
            git clone --depth 1 https://github.com/KhronosGroup/OpenCL-Headers.git "$ocl_headers"
        fi
        if [ ! -d "$ocl_loader/.git" ]; then
            echo "--- Descargando OpenCL-ICD-Loader ($OPENCL_LOADER_REF) ---"
            rm -rf "$ocl_loader"
            git clone --depth 1 --branch "$OPENCL_LOADER_REF" https://github.com/KhronosGroup/OpenCL-ICD-Loader.git "$ocl_loader"
        fi
    fi

    # Fetch tarball-based deps on demand
    if [[ "$requested_libs" == *" freetype "* || "$requested_libs" == *" libfreetype "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/freetype-2.13.2" "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz"
    fi
    if [[ "$requested_libs" == *" fribidi "* || "$requested_libs" == *" libfribidi "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/fribidi-1.0.13" "https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz"
    fi
    if [[ "$requested_libs" == *" harfbuzz "* || "$requested_libs" == *" libharfbuzz "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/harfbuzz-8.4.0" "https://github.com/harfbuzz/harfbuzz/releases/download/8.4.0/harfbuzz-8.4.0.tar.xz"
    fi
    if [[ "$requested_libs" == *" libass "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/libass-0.17.3" "https://github.com/libass/libass/releases/download/0.17.3/libass-0.17.3.tar.xz"
    fi
    if [[ "$requested_libs" == *" libdav1d "* || "$requested_libs" == *" dav1d "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/dav1d-1.4.2" "https://downloads.videolan.org/pub/videolan/dav1d/1.4.2/dav1d-1.4.2.tar.xz"
    fi
    if [[ "$requested_libs" == *" libvpx "* || "$requested_libs" == *" vpx "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/libvpx-1.13.1" "https://github.com/webmproject/libvpx/archive/refs/tags/v1.13.1.tar.gz"
    fi
    if [[ "$requested_libs" == *" libwebp "* || "$requested_libs" == *" webp "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/libwebp-1.3.2" "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.3.2.tar.gz"
    fi
    if [[ "$requested_libs" == *" libopenjpeg "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/openjpeg-2.5.2" "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.2.tar.gz"
    fi
    if [[ "$requested_libs" == *" zimg "* || "$requested_libs" == *" libzimg "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/zimg-release-3.0.5" "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.5.tar.gz"
    fi
    if [[ "$requested_libs" == *" libsoxr "* || "$requested_libs" == *" soxr "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/soxr-0.1.3-Source" "https://downloads.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz"
    fi
    if [[ "$requested_libs" == *" fontconfig "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/fontconfig-2.15.0" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz"
    fi
    if [[ "$requested_libs" == *" libmp3lame "* || "$requested_libs" == *" lame "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/lame-3.100" "https://download.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
    fi
    if [[ "$requested_libs" == *" libopus "* || "$requested_libs" == *" opus "* ]]; then
        fetch_src_if_missing "$SRC_ROOT/opus-1.4" "https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz"
    fi

    # x265 solo si está en la lista de libs solicitadas
    if [[ "$requested_libs" == *" libx265 "* ]]; then
        if [ -d "$SRC_ROOT/x265/.git" ] && [ ! -f "$SRC_ROOT/x265/source/CMakeLists.txt" ]; then
            rm -rf "$SRC_ROOT/x265"
        fi
        if [ ! -d "$SRC_ROOT/x265/.git" ]; then
            echo "--- Descargando x265 ($X265_REF) ---"
            rm -rf "$SRC_ROOT/x265"
            git clone --depth 1 --branch "$X265_REF" https://bitbucket.org/multicoreware/x265_git.git "$SRC_ROOT/x265"
        fi
    fi
}

# Garantiza herramientas de build (meson/ninja/cmake) cuando alguna lib las requiere.
function ensure_build_tools {
    local to_install=()

    command -v meson >/dev/null 2>&1 || to_install+=(meson)
    command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1 || to_install+=(ninja-build)
    command -v cmake >/dev/null 2>&1 || to_install+=(cmake)

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "[deps] Instalando herramientas: ${to_install[*]}" >&2
        apt-get update >/dev/null
        apt-get install -y "${to_install[@]}" >/dev/null
    fi
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

    # IMPORTANTE: en Docker Desktop sobre Windows, borrar directorios grandes dentro de un bind mount
    # puede fallar intermitentemente con "Directory not empty". Usa /tmp para el build.
    local builddir="/tmp/svt-av1-build"
    rm -rf "$builddir" >/dev/null 2>&1 || true

    cmake -S . -B "$builddir" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build "$builddir" -j"$(nproc)"
    cmake --install "$builddir"

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
    CFLAGS="-O3 -fPIC" LDFLAGS="" cmake -S . -B build -G Ninja \
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
    CFLAGS="-O3 -fPIC" LDFLAGS="" cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LOADER=ON \
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

function build_libvpl_static {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libvpl.a" ] || [ -f "$PREFIX/lib64/libvpl.a" ]; then
        return
    fi

    echo "--- Compilando oneVPL (libvpl) $VPL_REF ---"
    pushd "$SRC_ROOT/oneVPL" >/dev/null
    rm -rf build
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TOOLS=OFF \
        -DVPL_INSTALL_PKGCONFIG=ON
    cmake --build build -j"$(nproc)"
    cmake --install build
    popd >/dev/null
}

function build_libva_static {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libva.a" ] || [ -f "$PREFIX/lib64/libva.a" ]; then
        return
    fi

    echo "--- Compilando libva $LIBVA_REF (static) ---"
    if [ ! -f /usr/lib/x86_64-linux-gnu/libdrm.a ]; then
        echo "[deps] Instalando libdrm-dev para libva" >&2
        apt-get update >/dev/null
        apt-get install -y libdrm-dev >/dev/null
    fi
    local old_cflags=${CFLAGS:-}
    local old_ldflags=${LDFLAGS:-}
    pushd "$SRC_ROOT/libva" >/dev/null
    rm -rf build
    # Meson a veces deshabilita --version-script en entornos estáticos; fuerzalo para evitar
    # símbolos sin versión (VA_API_0.x) al enlazar.
    python3 - "$SRC_ROOT/libva/va/meson.build" <<'PY'
import re, sys, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    r"libva_link_args = \[\]\nlibva_link_depends = \[\]\nif cc.links\([\s\S]*?endif\n",
    flags=re.MULTILINE,
)
replacement = "libva_link_args = libva_sym_arg\nlibva_link_depends = libva_sym\n"
new_text, count = pattern.subn(replacement, text)
if count == 0 and "libva_link_args" in text:
    new_text = text.replace("libva_link_args = []", "libva_link_args = libva_sym_arg")
    new_text = new_text.replace("libva_link_depends = []", "libva_link_depends = libva_sym")

path.write_text(new_text, encoding="utf-8")
PY
    CFLAGS="-O3 -fPIC" LDFLAGS="" meson setup build \
        --prefix "$PREFIX" \
        --buildtype release \
        --default-library static \
        -Ddisable_drm=false -Dwith_x11=no -Dwith_glx=no -Dwith_wayland=no -Dwith_win32=no
    ninja -C build -j"$(nproc)"
    ninja -C build install
    # Meson siempre genera objetos compartidos para libva; reutiliza los .o para crear .a estáticos.
    local libdir="$PREFIX/lib"
    mkdir -p "$libdir"
    if compgen -G "build/va/libva.so*.p" >/dev/null; then
        ar -rcs "$libdir/libva.a" $(find build/va/libva.so*.p -name '*.o')
        command -v gcc-ranlib >/dev/null 2>&1 && gcc-ranlib "$libdir/libva.a"
    fi
    if [ -d "build/va/va-drm.p" ]; then
        ar -rcs "$libdir/libva-drm.a" $(find build/va/va-drm.p -name '*.o')
        command -v gcc-ranlib >/dev/null 2>&1 && gcc-ranlib "$libdir/libva-drm.a"
    fi
    CFLAGS="$old_cflags"
    LDFLAGS="$old_ldflags"
    popd >/dev/null
}

function build_opencl_static {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libOpenCL.a" ] || [ -f "$PREFIX/lib64/libOpenCL.a" ]; then
        return
    fi

    echo "--- Compilando OpenCL ICD Loader (static) $OPENCL_LOADER_REF ---"
    pushd "$SRC_ROOT/OpenCL-ICD-Loader" >/dev/null
    rm -rf build
    CFLAGS="-O3 -fPIC" LDFLAGS="" cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DOPENCL_ICD_LOADER_BUILD_TESTING=OFF \
        -DOPENCL_ICD_LOADER_HEADERS_DIR="$SRC_ROOT/OpenCL-Headers"
    cmake --build build -j"$(nproc)"
    cmake --install build
    popd >/dev/null
}

# --- Texto/subtítulos y codecs estáticos ---

build_freetype() {
    # Args: $PREFIX
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libfreetype.a" ] || [ -f "$PREFIX/lib64/libfreetype.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/freetype-2.13.2" >/dev/null
    ./configure \
        --prefix="$PREFIX" \
        --enable-static --disable-shared \
        --without-harfbuzz --without-bzip2 --without-brotli \
        --without-png-config
    make -j"$(nproc)"
    make install
    popd >/dev/null
}

build_fribidi() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libfribidi.a" ] || [ -f "$PREFIX/lib64/libfribidi.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/fribidi-1.0.13" >/dev/null
    rm -rf build
    meson setup build \
        --prefix "$PREFIX" \
        --buildtype release \
        --default-library static \
        -Ddocs=false -Dtests=false
    ninja -C build -j"$(nproc)"
    ninja -C build install
    popd >/dev/null
}

build_harfbuzz() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libharfbuzz.a" ] || [ -f "$PREFIX/lib64/libharfbuzz.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/harfbuzz-8.4.0" >/dev/null
    rm -rf build
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig" \
    meson setup build \
        --prefix "$PREFIX" \
        --buildtype release \
        --default-library static \
        -Dicu=disabled -Dgraphite=disabled -Dgobject=disabled -Dintrospection=disabled \
        -Dfreetype=enabled -Dglib=disabled -Ddocs=disabled -Dtests=disabled
    ninja -C build -j"$(nproc)"
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig" ninja -C build install
    popd >/dev/null
}

build_libass() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libass.a" ] || [ -f "$PREFIX/lib64/libass.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/libass-0.17.3" >/dev/null
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig" \
    ./configure \
        --prefix="$PREFIX" \
        --enable-static --disable-shared \
        --disable-test --disable-example \
        --disable-libunibreak \
        --with-harfbuzz=yes --with-freetype=yes --with-fribidi=yes
    make -j"$(nproc)"
    make install
    popd >/dev/null
}

build_dav1d() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libdav1d.a" ] || [ -f "$PREFIX/lib64/libdav1d.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/dav1d-1.4.2" >/dev/null
    rm -rf build
    meson setup build \
        --prefix "$PREFIX" \
        --buildtype release \
        --default-library static \
        -Denable_tools=false -Denable_tests=false
    ninja -C build -j"$(nproc)"
    ninja -C build install
    popd >/dev/null
}

build_soxr() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libsoxr.a" ] || [ -f "$PREFIX/lib64/libsoxr.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/soxr-0.1.3-Source" >/dev/null
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DWITH_LSR_BINDINGS=OFF \
        -DWITH_OPENMP=OFF
    cmake --build build -j"$(nproc)"
    cmake --install build
    popd >/dev/null
}

build_brotli() {
    local PREFIX=$1
    local libdir="$PREFIX/lib"
    [ -d "$PREFIX/lib64" ] && libdir="$PREFIX/lib64"

    if [ -f "$libdir/libbrotlienc.a" ] || [ -f "$libdir/libbrotlienc-static.a" ]; then
        return
    fi

    pushd "$SRC_ROOT/brotli-1.1.0" >/dev/null
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBROTLI_BUILD_SHARED_LIBS=OFF \
        -DBROTLI_BUILD_STATIC_LIBS=ON \
        -DBROTLI_BUILD_TESTS=OFF \
        -DBROTLI_BUILD_EXAMPLES=OFF
    cmake --build build -j"$(nproc)"
    cmake --install build

    # Normaliza nombres sin sufijo -static para facilitar pkg-config y enlace.
    for n in brotlidec brotlienc brotlicommon; do
        if [ -f "$libdir/lib${n}-static.a" ] && [ ! -f "$libdir/lib${n}.a" ]; then
            ln -sf "lib${n}-static.a" "$libdir/lib${n}.a"
        fi
    done

    mkdir -p "$libdir/pkgconfig"
    local bro_ver="1.1.0"
    cat >"$libdir/pkgconfig/libbrotlicommon.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/$(basename "$libdir")
includedir=\${prefix}/include

Name: libbrotlicommon
Description: Brotli common library
Version: $bro_ver
Libs: -L\${libdir} -lbrotlicommon
Libs.private: -lm
Cflags: -I\${includedir}
EOF

    cat >"$libdir/pkgconfig/libbrotlidec.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/$(basename "$libdir")
includedir=\${prefix}/include

Name: libbrotlidec
Description: Brotli decoder library
Version: $bro_ver
Requires.private: libbrotlicommon
Libs: -L\${libdir} -lbrotlidec -lbrotlicommon
Libs.private: -lm
Cflags: -I\${includedir}
EOF

    cat >"$libdir/pkgconfig/libbrotlienc.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/$(basename "$libdir")
includedir=\${prefix}/include

Name: libbrotlienc
Description: Brotli encoder library
Version: $bro_ver
Requires.private: libbrotlicommon
Libs: -L\${libdir} -lbrotlienc -lbrotlicommon
Libs.private: -lm
Cflags: -I\${includedir}
EOF
    popd >/dev/null
}

build_x265() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libx265.a" ] || [ -f "$PREFIX/lib64/libx265.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/x265" >/dev/null
    rm -rf build && mkdir -p build/8bit
    pushd build/8bit >/dev/null
    cmake -G Ninja ../../source \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DENABLE_HDR10_PLUS=OFF
    ninja -j"$(nproc)"
    ninja install
    # Upstream x265 no instala x265.pc cuando se compila solo en modo estático;
    # generamos un pkg-config mínimo para que FFmpeg lo detecte.
    local libdir="$PREFIX/lib"
    [ -d "$PREFIX/lib64" ] && libdir="$PREFIX/lib64"
    mkdir -p "$libdir/pkgconfig"
    local x265_ver
    x265_ver=$(grep -E '^#define X265_VERSION' "$PREFIX/include/x265.h" | awk '{print $3}' | tr -d '"' || echo "${X265_REF#Release_}")
    cat >"$libdir/pkgconfig/x265.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/$(basename "$libdir")
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC encoder library
Version: ${x265_ver:-3.5}
Libs: -L\${libdir} -lx265
Libs.private: -lstdc++ -lm
Cflags: -I\${includedir}
EOF
    popd >/dev/null
    popd >/dev/null
}

build_libxml2() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libxml2.a" ] || [ -f "$PREFIX/lib64/libxml2.a" ]; then
        return
    fi
    pushd "$SRC_ROOT/libxml2-2.12.7" >/dev/null
    ./configure \
        --prefix="$PREFIX" \
        --enable-static --disable-shared \
        --without-python --without-lzma --with-zlib
    make -j"$(nproc)"
    make install
    popd >/dev/null
}

build_libssh_static() {
    local PREFIX=$1
    if [ -f "$PREFIX/lib/libssh.a" ] || [ -f "$PREFIX/lib64/libssh.a" ]; then
        return
    fi
    local src="$SRC_ROOT/libssh"
    if [ ! -d "$src/.git" ] && [ ! -f "$src/CMakeLists.txt" ]; then
        rm -rf "$src"
        # Official git.libssh.org is often unreachable; fall back to GitHub mirror.
        if [ ! -d "$src/.git" ]; then
            rm -rf "$src"
        fi
        local urls=(
            "https://github.com/libssh/libssh.git"
            "https://gitlab.com/libssh/libssh-mirror/libssh.git"
        )
        for url in "${urls[@]}"; do
            if git clone --depth 1 --branch stable-0.10 "$url" "$src"; then
                break
            else
                rm -rf "$src"
            fi
        done
    fi
    pushd "$src" >/dev/null
    rm -rf build && mkdir -p build
    pushd build >/dev/null
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig" \
    cmake -G Ninja .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_EXAMPLES=OFF \
        -DWITH_TESTING=OFF \
        -DWITH_GSSAPI=OFF \
        -DWITH_SFTP=ON \
        -DWITH_ZLIB=ON \
        -DWITH_PCAP=OFF
    cmake --build . -j"$(nproc)"
    cmake --install .
    popd >/dev/null
    popd >/dev/null
}

function install_static_pc_shim_libssh {
    # FFmpeg (configure) puede fallar con libssh en modo -static si la .pc del sistema no
    # arrastra correctamente dependencias de OpenSSL. Este shim fuerza esas deps en Libs.
    # Recibe: $PREFIX (dist prefix del proyecto)
    local PREFIX=$1
    local pcdir="$PREFIX/lib/pkgconfig"
    mkdir -p "$pcdir"

    # Lee metadata desde el pkg-config del sistema (si existe) para mantener versión/rutas.
    local sys_ver sys_libdir sys_incdir sys_libs
    sys_ver=$(pkg-config --modversion libssh 2>/dev/null || echo "0.6.0")
    sys_libdir=$(pkg-config --variable=libdir libssh 2>/dev/null || echo "/usr/lib/x86_64-linux-gnu")
    sys_incdir=$(pkg-config --variable=includedir libssh 2>/dev/null || echo "/usr/include")
    sys_libs=$(pkg-config --static --libs libssh 2>/dev/null || echo "-lssh")
    local lib_search=(${sys_libdir:-} /usr/lib/x86_64-linux-gnu /usr/lib /lib/x86_64-linux-gnu /lib)

    # Algunos empaquetados de libssh no incluyen GSSAPI en Libs.private para --static;
    # añade las dependencias explícitas si existen en el sistema para evitar símbolos
    # gss_* faltantes en los tests estáticos de FFmpeg.
    for dep in -lgssapi_krb5 -lkrb5 -lk5crypto -lcom_err -lkrb5support -lresolv; do
        local name=${dep#-l}
        local has_static=0
        for d in "${lib_search[@]}"; do
            [ -z "$d" ] && continue
            if [ -f "$d/lib${name}.a" ]; then
                has_static=1
                break
            fi
        done
        [ "$has_static" -eq 0 ] && continue
        if [[ " $sys_libs " != *" $dep "* ]]; then
            sys_libs+=" $dep"
        fi
    done

    # Fuerza OpenSSL si el .pc del sistema no lo expone (esto evita fallos por BN_*/CRYPTO_*).
    if [[ " $sys_libs " != *" -lssl "* ]]; then
        sys_libs+=" -lssl"
    fi
    if [[ " $sys_libs " != *" -lcrypto "* ]]; then
        sys_libs+=" -lcrypto"
    fi

    cat >"$pcdir/libssh.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${sys_libdir}
includedir=${sys_incdir}

Name: libssh
Description: libssh (static shim for FFmpeg)
Version: ${sys_ver}
Libs: ${sys_libs}
Cflags: -I\${includedir}
EOF

    echo "[linux-deps] Instalado shim libssh.pc en $pcdir (Version: ${sys_ver})" >&2
    PKG_CONFIG_PATH="$pcdir:${PKG_CONFIG_PATH:-}" pkg-config --static --libs libssh 2>/dev/null | sed 's/^/[linux-deps] libssh --static --libs: /' >&2 || true
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
    local debug=${FFMPEG_FEATURE_FLAGS_DEBUG:-0}

    log_feature() {
        [ "$debug" = "1" ] && echo "[features] $*" >&2
    }

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

        # En builds 100% estáticos (-static), aceptamos dependencias provistas por el sistema
        # SIEMPRE QUE pkg-config --static exponga libs y todas tengan su correspondiente lib*.a
        # (esto evita que se habiliten libs que terminarían dependiendo de .so en tiempo de enlace).

        # Toolchain/system libs that may not have a matching lib*.a in the same libdir.
        local allow_missing=(c gcc_s m pthread dl rt resolv util stdc++ atomic)

        local libdirs=()
        local pc_libdir=""
        if [ -n "$pkg_libdir" ]; then
            pc_libdir=$(PKG_CONFIG_PATH="$pkg_path" PKG_CONFIG_LIBDIR="$pkg_libdir" pkg-config --variable=libdir "$pkg" 2>/dev/null || true)
        else
            pc_libdir=$(PKG_CONFIG_PATH="$pkg_path" pkg-config --variable=libdir "$pkg" 2>/dev/null || true)
        fi
        [ -n "$pc_libdir" ] && libdirs+=("$pc_libdir")

        while IFS= read -r token; do
            [ -z "$token" ] && continue
            case "$token" in
                -L*) libdirs+=("${token#-L}") ;;
            esac
        done < <(
            if [ -n "$pkg_libdir" ]; then
                PKG_CONFIG_PATH="$pkg_path" PKG_CONFIG_LIBDIR="$pkg_libdir" pkg-config --static --libs "$pkg" 2>/dev/null
            else
                PKG_CONFIG_PATH="$pkg_path" pkg-config --static --libs "$pkg" 2>/dev/null
            fi | tr ' ' '\n'
        )

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

        # Algunos .pc (p.ej. zlib en Ubuntu) no declaran libdir ni emiten -L, porque confían en
        # las rutas por defecto del linker. En ese caso, usa rutas estándar para validar lib*.a.
        if [ "${#libdirs[@]}" -eq 0 ]; then
            if [ -n "${PREFIX:-}" ]; then
                [ -d "$PREFIX/lib" ] && libdirs+=("$PREFIX/lib")
                [ -d "$PREFIX/lib64" ] && libdirs+=("$PREFIX/lib64")
            fi
            for d in /usr/lib/x86_64-linux-gnu /usr/lib /lib/x86_64-linux-gnu /lib; do
                [ -d "$d" ] && libdirs+=("$d")
            done
        else
            # Aún con -L presentes, incluir rutas estándar evita falsos negativos.
            for d in /usr/lib/x86_64-linux-gnu /usr/lib /lib/x86_64-linux-gnu /lib; do
                [ -d "$d" ] && libdirs+=("$d")
            done
        fi

        # Dedup de nuevo tras añadir rutas estándar
        if [ "${#libdirs[@]}" -gt 0 ]; then
            local dedup2=()
            local seen2=""
            for d in "${libdirs[@]}"; do
                [[ ":$seen2:" == *":$d:"* ]] && continue
                seen2+="$d:"
                dedup2+=("$d")
            done
            libdirs=("${dedup2[@]}")
        fi

        [ "${#libdirs[@]}" -eq 0 ] && return 1

        while IFS= read -r libflag; do
            [ -z "$libflag" ] && continue
            local name=${libflag#-l}
            [ -z "$name" ] && continue
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
        done < <(
            if [ -n "$pkg_libdir" ]; then
                PKG_CONFIG_PATH="$pkg_path" PKG_CONFIG_LIBDIR="$pkg_libdir" pkg-config --static --libs-only-l "$pkg" 2>/dev/null
            else
                PKG_CONFIG_PATH="$pkg_path" pkg-config --static --libs-only-l "$pkg" 2>/dev/null
            fi | tr ' ' '\n'
        )

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
                    log_feature "enable ${label} via pkg=${pkg}"
                    found=1
                    break
                else
                    any_nonstatic=1
                fi
            fi
        done

        if [ "$found" -eq 0 ]; then
            if [ "$want_static" -eq 1 ] && [ "$any_nonstatic" -eq 1 ]; then
                echo "[WARN] ${label} detectado pero no linkeable estáticamente; omitiendo" >&2
                log_feature "skip ${label}: non-static"
            elif [ "$any_exists" -eq 1 ]; then
                echo "[WARN] ${label} detectado pero no usable; omitiendo" >&2
                log_feature "skip ${label}: unusable"
            else
                echo "[WARN] ${label} no encontrado; omitiendo" >&2
                log_feature "skip ${label}: missing"
            fi
        fi
    }

    for lib in $libs; do
        case "$lib" in
            x264)
                flags+=" --enable-libx264 --enable-gpl"
                ;;
            libx265)
                add_flag_if_pkg "--enable-libx265" "x265" libx265
                ;;
            libsvtav1)
                # FFmpeg requiere SvtAv1Enc >= 0.9.0; valida versión para evitar que configure falle.
                add_flag_if_pkg "--enable-libsvtav1" "libsvtav1" "SvtAv1Enc >= 0.9.0" SvtAv1Enc svtav1
                ;;
            libdav1d)
                add_flag_if_pkg "--enable-libdav1d" "dav1d" libdav1d
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
                add_flag_if_pkg "--enable-libsoxr" "soxr" libsoxr
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
                else
                    echo "[WARN] ffmpeg $FFMPEG_VER no expone --enable-brotli; omitiendo" >&2
                    log_feature "skip brotli: flag not supported by configure"
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
                if [ -n "${FFMPEG_DISABLE_NVENC:-}" ]; then
                    echo "[WARN] nvcodec deshabilitado por FFMPEG_DISABLE_NVENC=1; omitiendo" >&2
                elif [ "$target" = "linux" ]; then
                    prepare_nvcodec_headers "/usr/local" >/dev/null
                    flags+=" --enable-ffnvcodec --enable-nvenc"
                else
                    if [ -n "${FFMPEG_ALLOW_NVENC:-}" ]; then
                        prepare_nvcodec_headers >/dev/null
                        flags+=" --enable-ffnvcodec --enable-nvenc"
                    else
                        echo "[WARN] nvcodec omitido (set FFMPEG_ALLOW_NVENC=1 para habilitarlo)" >&2
                    fi
                fi
                ;;
            vaapi)
                # VAAPI suele no ser enlazable de forma 100% estática con paquetes de distro.
                # Si estamos forzando -static, evita romper configure a menos que exista libva.a.
                if pkg_usable libva; then
                    flags+=" --enable-vaapi"
                else
                    local va_libdir=""
                    va_libdir=$(PKG_CONFIG_PATH="$pkg_path" pkg-config --variable=libdir libva 2>/dev/null || true)
                    for d in "$PREFIX/lib" "$PREFIX/lib64" "$va_libdir"; do
                        if [ -n "$d" ] && [ -f "$d/libva.a" ]; then
                            flags+=" --enable-vaapi"
                            log_feature "enable vaapi via libva.a fallback"
                            va_libdir="$d"
                            break
                        fi
                    done

                    if [[ " $flags " != *" --enable-vaapi "* ]]; then
                        echo "[WARN] vaapi omitido en build estático (libva.a no disponible)" >&2
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
                    local vk_lib=""
                    for d in "$PREFIX/lib" "$PREFIX/lib64"; do
                        if [ -f "$d/libvulkan.a" ]; then
                            vk_lib="$d/libvulkan.a"
                            break
                        fi
                    done

                    if [ -n "$vk_lib" ]; then
                        flags+=" --enable-vulkan"
                        log_feature "enable vulkan via libvulkan.a fallback"
                    else
                        echo "[WARN] vulkan >= 1.3.277 no encontrado; omitiendo" >&2
                    fi
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