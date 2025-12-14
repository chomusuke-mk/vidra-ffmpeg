#!/bin/bash
# scripts/platforms/linux.sh

source /build/scripts/common_libs.sh

function build_linux {
    echo ">>> Iniciando compilación para LINUX (Nativo x86_64) <<<"

    load_config
    ensure_sources

    export PREFIX="/build/dist/linux"
    # Incluye lib64 por si alguna dependencia instala allí su .pc
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"

    # Por defecto, Linux exporta un binario lo más estático posible.
    # Puedes desactivar el fully-static con: FFMPEG_LINUX_STATIC=0
    local linux_static=${FFMPEG_LINUX_STATIC:-1}
    local pkg_config_flags=""
    local extra_cflags="-Wno-stringop-overflow -Wno-array-bounds"
    local extra_ldflags=""
    local ff_cfg_static_flags=""

    if [ "$linux_static" = "1" ]; then
        export CFLAGS="-O3 -static"
        export LDFLAGS="-static"
        pkg_config_flags="--pkg-config-flags=\"--static\""
        extra_cflags="-static $extra_cflags"
        extra_ldflags="-static"
        ff_cfg_static_flags="--enable-static --disable-shared"
    else
        export CFLAGS="-O3"
        export LDFLAGS=""
        # Mantén FFmpeg estático internamente para exportar un único binario (pero dinámico contra glibc).
        ff_cfg_static_flags="--enable-static --disable-shared"
    fi

    mkdir -p "$PREFIX"

    echo "--- Compilando x264 ---"
    if [ "$linux_static" = "1" ]; then
        build_x264 "x86_64-linux-gnu" "$PREFIX" "--disable-asm"
    else
        build_x264 "x86_64-linux-gnu" "$PREFIX" "--enable-pic --disable-asm"
    fi

    for build_variant in ${FFMPEG_BUILDS_LIST:-standard}; do
        echo "[linux] Build variant: $build_variant"

        local libs feature_flags output_dir version_dir extra_version_flag
        libs=$(collect_target_libs "linux" "$build_variant")

        if [[ " $libs " == *" libsvtav1 "* ]]; then
            build_svtav1 "$PREFIX"
        fi

        if [[ " $libs " == *" vulkan "* ]]; then
            build_vulkan "$PREFIX"
        fi

        feature_flags=$(ffmpeg_feature_flags "linux" "$libs")
        extra_version_flag=$(ffmpeg_extra_version_flag "$build_variant")
        version_dir=$(version_dir_for_variant "$build_variant")
        output_dir="/output/${version_dir}/linux"

        mkdir -p "$output_dir"

        echo "--- Compilando FFmpeg ---"
        cd /build/sources/ffmpeg-$FFMPEG_VER

        make distclean >/dev/null 2>&1 || true
        ./configure \
            --prefix=$PREFIX \
            ${pkg_config_flags:+$pkg_config_flags} \
            --enable-gpl \
            --enable-version3 \
            $ff_cfg_static_flags \
            --disable-debug \
            --disable-ffplay \
            --disable-doc \
            --extra-cflags="$extra_cflags" \
            ${extra_ldflags:+--extra-ldflags="$extra_ldflags"} \
            ${extra_version_flag:+$extra_version_flag} \
            $feature_flags

        make -j$(nproc)

        echo "--- Exportando resultado ---"
        cp ffmpeg "$output_dir/ffmpeg"

        if command -v file >/dev/null 2>&1 && file "$output_dir/ffmpeg" | grep -qi "statically linked"; then
            echo "ÉXITO: El binario es estático."
        else
            if [ "$linux_static" = "1" ]; then
                echo "[WARN] El binario no parece 100% estático; revisa dependencias." >&2
            else
                echo "INFO: El binario es dinámico (modo shared)."
            fi
        fi
    done
}