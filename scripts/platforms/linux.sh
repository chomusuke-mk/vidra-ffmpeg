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

    local libs feature_flags extra_version_flag output_dir
    libs=$(collect_target_libs "linux")
    feature_flags=$(ffmpeg_feature_flags "linux" "$libs")
    extra_version_flag=$(ffmpeg_extra_version_flag)
    output_dir="/output/${FFMPEG_VER}/linux"

    mkdir -p "$PREFIX" "$output_dir"

    echo "--- Compilando x264 ---"
    build_x264 "x86_64-linux-gnu" "$PREFIX" "--disable-asm"

    echo "--- Compilando FFmpeg ---"
    cd /build/sources/ffmpeg-$FFMPEG_VER

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
}