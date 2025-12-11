#!/bin/bash
# scripts/platforms/linux.sh

source /build/scripts/common_libs.sh

function build_linux {
    echo ">>> Iniciando compilación para LINUX (Nativo x86_64) <<<"

    load_config
    ensure_sources

    export PREFIX="/build/dist/linux"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
    export CFLAGS="-O3 -static"
    export LDFLAGS="-static"

    mkdir -p "$PREFIX"

    echo "--- Compilando x264 ---"
    build_x264 "x86_64-linux-gnu" "$PREFIX" "--disable-asm"

    for build_variant in ${FFMPEG_BUILDS_LIST:-standard}; do
        echo "[linux] Build variant: $build_variant"

        local libs feature_flags output_dir version_dir extra_version_flag
        libs=$(collect_target_libs "linux" "$build_variant")
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
            --pkg-config-flags="--static" \
            --enable-gpl \
            --enable-version3 \
            --enable-static \
            --disable-shared \
            --disable-debug \
            --disable-ffplay \
            --disable-doc \
            --extra-cflags="-static" \
            --extra-ldflags="-static" \
            ${extra_version_flag:+$extra_version_flag} \
            $feature_flags

        make -j$(nproc)

        echo "--- Exportando resultado ---"
        cp ffmpeg "$output_dir/ffmpeg"

        if ldd "$output_dir/ffmpeg" | grep "not a dynamic executable"; then
            echo "ÉXITO: El binario es estático."
        else
            echo "ADVERTENCIA: El binario podría tener dependencias dinámicas."
        fi
    done
}