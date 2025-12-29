#!/bin/bash
# scripts/platforms/linux.sh

source /build/scripts/common_libs.sh

function build_linux {
    load_config
    build_variant=${FFMPEG_BUILD:-standard}
    echo ">>> Iniciando compilación para LINUX (Nativo x86_64) [$build_variant] <<<"
    echo "[linux] Build variant: $build_variant"

    ensure_sources
    ensure_build_tools

    export PREFIX="/build/dist/linux"
    # Incluye lib64 y multiarch (x86_64-linux-gnu) por si alguna dependencia instala allí su .pc
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:$PREFIX/lib/x86_64-linux-gnu/pkgconfig"

    # Por defecto, Linux exporta un binario lo más estático posible.
    # Puedes desactivar el fully-static con: FFMPEG_LINUX_STATIC=0
    local linux_static=${FFMPEG_LINUX_STATIC:-1}
    local pkg_config_flags=""
    local extra_cflags="-Wno-stringop-overflow -Wno-array-bounds -Wno-unused-function"
    # Siempre empuja el prefix al rpath de compilación para que los checks de ffmpeg encuentren .a/.h
    local extra_ldflags="-L$PREFIX/lib -L$PREFIX/lib64"
    local extra_libs=""
    local ff_cfg_static_flags=""

    if [ "$linux_static" = "1" ]; then
        export CFLAGS="-O3 -static"
        export LDFLAGS="-static"
        pkg_config_flags="--pkg-config-flags=--static"
        extra_cflags="-static $extra_cflags"
        extra_ldflags="-static $extra_ldflags"
        # `configure` a veces hace pruebas de enlace con solo -l<lib> (sin arrastrar deps de pkg-config).
        # En estático eso rompe fácil (ej: libssh requiere símbolos de libcrypto/libssl).
        # Mantén este set pequeño y de libs de toolchain/sistema que suelen existir.
        extra_libs="-lssl -lcrypto -lz -ldl -lm -lpthread -lstdc++ -latomic"
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

    local libs feature_flags output_dir version_dir extra_version_flag
    libs=$(collect_target_libs "linux" "$build_variant")
    if [[ " $libs " == *" brotli "* ]]; then
        build_brotli "$PREFIX"
    fi
    if [[ " $libs " == *" libvpl "* ]]; then
        build_libvpl_static "$PREFIX"
    fi
    if [[ " $libs " == *" vaapi "* ]]; then
        build_libva_static "$PREFIX"
    fi
    if [[ " $libs " == *" opencl "* ]]; then
        build_opencl_static "$PREFIX"
    fi

    # Texto/subtítulos
    if [[ " $libs " == *" freetype "* || " $libs " == *" libfreetype "* ]]; then
        build_freetype "$PREFIX"
    fi
    if [[ " $libs " == *" fribidi "* || " $libs " == *" libfribidi "* ]]; then
        build_fribidi "$PREFIX"
    fi
    if [[ " $libs " == *" harfbuzz "* || " $libs " == *" libharfbuzz "* ]]; then
        build_harfbuzz "$PREFIX"
    fi
    if [[ " $libs " == *" libass "* ]]; then
        build_libass "$PREFIX"
    fi

    # Codecs adicionales
    if [[ " $libs " == *" dav1d "* || " $libs " == *" libdav1d "* ]]; then
        build_dav1d "$PREFIX"
    fi
        if [[ " $libs " == *" soxr "* || " $libs " == *" libsoxr "* ]]; then
            build_soxr "$PREFIX"
        fi
        if [[ " $libs " == *" libx265 "* ]]; then
            build_x265 "$PREFIX"
        fi
        if [[ " $libs " == *" libxml2 "* ]]; then
            build_libxml2 "$PREFIX"
        fi

        # Verifica disponibilidad de pkg-config para libs críticas antes de configurar FFmpeg
        echo "[linux-debug] PKG_CONFIG_PATH=$PKG_CONFIG_PATH" >&2
        for pc in dav1d soxr x265 libdav1d libsoxr libx265; do
            if PKG_CONFIG_PATH="$PKG_CONFIG_PATH" pkg-config --exists "$pc"; then
                echo "[linux-debug] pkg-config ok: $pc" >&2
            else
                echo "[linux-debug] pkg-config missing: $pc" >&2
            fi
        done

        if [ "$linux_static" = "1" ] && [[ " $libs " == *" libssh "* ]]; then
            if [ ! -f "/usr/lib/x86_64-linux-gnu/libgssapi_krb5.a" ] && [ ! -f "/usr/lib/x86_64-linux-gnu/libgssapi_krb5.so" ]; then
                echo "[ERROR] Falta libkrb5-dev (GSSAPI) en la imagen. Rebuild Docker para incluirlo." >&2
                exit 1
            fi
            build_libssh_static "$PREFIX"
            install_static_pc_shim_libssh "$PREFIX"
        fi

        if [[ " $libs " == *" libsvtav1 "* ]]; then
            build_svtav1 "$PREFIX"
        fi

        if [[ " $libs " == *" vulkan "* ]]; then
            build_vulkan "$PREFIX"
        fi

        feature_flags=$(ffmpeg_feature_flags "linux" "$libs")

        # En modo estático, la autodetección puede ser demasiado conservadora.
        # Si el usuario pidió explícitamente vaapi/vulkan y ya compilamos sus deps,
        # fuerza los flags para que queden reflejados en la configuración final.
        local forced_flags=""
        if [[ " $libs " == *" vaapi "* ]]; then
            if [[ " $feature_flags " != *" --enable-vaapi "* ]]; then
                forced_flags+=" --enable-vaapi"
            fi
        fi
        if [[ " $libs " == *" vulkan "* ]]; then
            if [[ " $feature_flags " != *" --enable-vulkan "* ]]; then
                forced_flags+=" --enable-vulkan"
            fi
        fi
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
            ${extra_libs:+--extra-libs="$extra_libs"} \
            ${extra_version_flag:+$extra_version_flag} \
            $feature_flags \
            $forced_flags

        make -j$(nproc)

        echo "--- Exportando resultado ---"
        cp ffmpeg "$output_dir/ffmpeg"
        cp ffprobe "$output_dir/ffprobe"

        if command -v file >/dev/null 2>&1 && file "$output_dir/ffmpeg" | grep -qi "statically linked"; then
            echo "ÉXITO: El binario es estático."
        else
            if [ "$linux_static" = "1" ]; then
                echo "[WARN] El binario no parece 100% estático; revisa dependencias." >&2
            else
                echo "INFO: El binario es dinámico (modo shared)."
            fi
        fi
}