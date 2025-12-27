#!/bin/bash
source /build/scripts/common_libs.sh

WIN_SYSROOT_BASE="/usr/x86_64-w64-mingw32"
WIN_SYSROOT="$WIN_SYSROOT_BASE/mingw64"
WIN_PKG_CONFIG_LIBDIR="$WIN_SYSROOT/lib/pkgconfig:$WIN_SYSROOT/share/pkgconfig:/build/dist/windows/lib/pkgconfig"

function prepare_win_sysroot {
    local marker="$WIN_SYSROOT/.vidra-msys2.ready"
    local sanity_pcs=(
        "$WIN_SYSROOT/lib/pkgconfig/libxml-2.0.pc"
        "$WIN_SYSROOT/lib/pkgconfig/libvpl.pc"
    )
    local missing=0
    for pc in "${sanity_pcs[@]}"; do
        if [ ! -f "$pc" ]; then
            missing=1
            break
        fi
    done

    if [ -f "$marker" ] && [ "$missing" -eq 0 ]; then
        echo "[win-deps] Sysroot ya preparado ($marker)"
        return
    fi

    if [ ! -x /build/scripts/deps/windows/fetch_msys2.sh ]; then
        echo "[win-deps] ERROR: fetch_msys2.sh no encontrado o sin permisos en /build/scripts/deps/windows" >&2
        exit 1
    fi

    echo "[win-deps] Preparando sysroot mingw desde MSYS2"
    bash /build/scripts/deps/windows/fetch_msys2.sh
}

function build_windows {
    echo ">>> Iniciando compilación para WINDOWS (x86_64) <<<"

    echo "[win-deps] Politica: se intenta binario 100% estático; si alguna lib solo existe como DLL, debe ir junto a ffmpeg.exe con su licencia."

    load_config
    ensure_sources

    prepare_win_sysroot

    # ld with -static ignores *.dll.a; add .a aliases for libplacebo deps
    for alias in libshaderc_shared libspirv-cross-c-shared libvulkan-1; do
        if [ -f "$WIN_SYSROOT/lib/${alias}.dll.a" ] && [ ! -f "$WIN_SYSROOT/lib/${alias}.a" ]; then
            ln -sf "${alias}.dll.a" "$WIN_SYSROOT/lib/${alias}.a"
        fi
    done

    export CROSS_PREFIX=x86_64-w64-mingw32-
    export CC="${CROSS_PREFIX}gcc"
    export CXX="${CROSS_PREFIX}g++"
    export PREFIX="/build/dist/windows"
    # pkg-config in the container honors PKG_CONFIG_PATH reliably; include sysroot + dist
    export PKG_CONFIG_PATH="$WIN_PKG_CONFIG_LIBDIR"
    export PKG_CONFIG_LIBDIR="$WIN_PKG_CONFIG_LIBDIR"
    export PKG_CONFIG_SYSROOT_DIR="$WIN_SYSROOT_BASE"
    export LDFLAGS="-static-libgcc -static-libstdc++"

    # Wrap pkg-config to strip any stray libgcc_s references that would reintroduce DLL deps
    local real_pkgconfig pkgconf_wrapper
    real_pkgconfig=$(command -v pkg-config)
    pkgconf_wrapper=/tmp/pkg-config-win-static.sh
    cat > "$pkgconf_wrapper" <<'EOF'
#!/usr/bin/env bash
set -e
real_pkgconfig="__PKGCONFIG_BIN__"
out=$("$real_pkgconfig" "$@" 2>/dev/null)
status=$?
if [ "$status" -ne 0 ]; then
    exit "$status"
fi
printf '%s\n' "$out" | sed -E 's/(^|[[:space:]])-lgcc_s([^[:space:]]*)//g' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//'
EOF
    sed -i "s|__PKGCONFIG_BIN__|$real_pkgconfig|g" "$pkgconf_wrapper"
    chmod +x "$pkgconf_wrapper"
    export PKG_CONFIG="$pkgconf_wrapper"

    mkdir -p "$PREFIX" "$PREFIX/lib"

    # Small shim to provide stat64/wstat64 aliases expected by some static libs (e.g. libxml2)
    local compat_src=/tmp/compat_stat64.c
    local compat_lib="$PREFIX/lib/libcompatstat64.a"
    cat > "$compat_src" <<'EOF'
#include <sys/stat.h>
#include <wchar.h>
#include <stdio.h>
#include <io.h>
#include <pthread.h>
#include <time.h>

// MSYS2 static libs (e.g., libxml2, libbluray) reference legacy CRT symbols
// that UCRT omits; provide thin aliases to the available underscored variants.
#undef stat64
#undef wstat64
#undef wstat64i32

int stat64(const char *path, struct _stat64 *buf) { return _stat64(path, buf); }
int wstat64(const wchar_t *path, struct _stat64 *buf) { return _wstat64(path, buf); }
int wstat64i32(const wchar_t *path, struct _stat64i32 *buf) { return _wstat64i32(path, buf); }

// Some mingw ports (e.g., librist) look for *_time64 variants; map to the
// available winpthreads/time implementations to keep static linking working.
int clock_gettime64(clockid_t clk_id, struct timespec *tp) { return clock_gettime(clk_id, tp); }
int pthread_cond_timedwait64(pthread_cond_t *cond, pthread_mutex_t *mutex, const struct timespec *abstime) {
    return pthread_cond_timedwait(cond, mutex, abstime);
}

// openjpeg from MSYS2 pulls import pointers for fseeko64/ftello64; provide the
// __imp_* aliases pointing to the existing mingwex implementations to avoid
// missing symbols without redefining the functions (which are already present
// in libmingwex for UCRT).
int fseeko64(FILE *stream, _off64_t offset, int whence);
_off64_t ftello64(FILE *stream);

int (__cdecl *__imp_fseeko64)(FILE *, _off64_t, int) = fseeko64;
_off64_t (__cdecl *__imp_ftello64)(FILE *) = ftello64;

// Provide the import symbols expected by objects built with dllimport decoration.
int (__cdecl *__imp__wstat64i32)(const wchar_t *, struct _stat64i32 *) = wstat64i32;
EOF
    ${CC} -c "$compat_src" -o /tmp/compat_stat64.o
    ar rcs "$compat_lib" /tmp/compat_stat64.o

    build_x264 "x86_64-w64-mingw32" "$PREFIX" "--cross-prefix=${CROSS_PREFIX} --disable-asm"

    for build_variant in ${FFMPEG_BUILDS_LIST:-standard}; do
        echo "[win] Build variant: $build_variant"

        local libs feature_flags version_dir output_dir extra_version_flag
        libs=$(collect_target_libs "windows" "$build_variant")
        # Enable NVENC/ffnvcodec automatically when requested in config.sh for Windows builds.
        if [[ " $libs " == *" nvcodec "* ]] && [ -z "${FFMPEG_ALLOW_NVENC:-}" ]; then
            export FFMPEG_ALLOW_NVENC=1
        fi
        feature_flags=$(ffmpeg_feature_flags "windows" "$libs")
        if [ -n "$libs" ] && [ -z "$feature_flags" ]; then
            echo "[win-deps] ERROR: No se resolvieron flags para las libs solicitadas ($libs). Revisa pkg-config paths y sysroot." >&2
            exit 1
        fi

        extra_version_flag=$(ffmpeg_extra_version_flag "$build_variant")
        version_dir=$(version_dir_for_variant "$build_variant")
        output_dir="/output/${version_dir}/windows"
        mkdir -p "$output_dir"

        cd /build/sources/ffmpeg-$FFMPEG_VER
        make distclean >/dev/null 2>&1 || true
        ./configure \
            --target-os=mingw32 \
            --arch=x86_64 \
            --cross-prefix=$CROSS_PREFIX \
            --prefix=$PREFIX \
            --pkg-config=$PKG_CONFIG \
            --pkg-config-flags="--static" \
            --enable-gpl \
            --enable-version3 \
            --disable-w32threads \
            --enable-pthreads \
            ${extra_version_flag:+$extra_version_flag} \
            --enable-static --disable-shared \
            --disable-debug --disable-doc --disable-manpages --disable-htmlpages \
            --disable-ffplay\
            --extra-cflags="-static -std=gnu11 -I$PREFIX/include -I$WIN_SYSROOT/include -DLIBSSH_STATIC ${MINGW_SUPPRESS_WARNINGS:-}" \
            --extra-ldflags="-static -static-libgcc -static-libstdc++ -L$PREFIX/lib -L$WIN_SYSROOT/lib -pthread" \
            --extra-libs="-static-libgcc -static-libstdc++ -lcompatstat64 -lgomp -lssl -lcrypto -lz -lws2_32 -lcrypt32 -liconv -lgdi32 -lbcrypt -liphlpapi -lmingwex -lucrtbase -lstdc++ -lwinpthread" \
            $feature_flags

        make -j$(nproc)

        cp ffmpeg.exe "$output_dir/ffmpeg.exe"
    done
}