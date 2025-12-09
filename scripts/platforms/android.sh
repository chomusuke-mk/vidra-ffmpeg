#!/bin/bash
# scripts/platforms/android.sh

source /build/scripts/common_libs.sh

# Build base libs for a given ABI to avoid manual, per-lib invocations.
build_android_base_libs() {
    local ABI=$1 API=$2 NDK=$3 PREFIX=$4 SRC=$5
    local TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

    local TARGET_HOST
    case "$ABI" in
        arm64-v8a) TARGET_HOST="aarch64-linux-android";;
        armeabi-v7a|arm|armv7-a|arm-v7n) TARGET_HOST="armv7a-linux-androideabi";;
        x86) TARGET_HOST="i686-linux-android";;
        x86_64) TARGET_HOST="x86_64-linux-android";;
        *) echo "[WARN] ABI base libs not supported: $ABI" >&2; return 1;;
    esac

    mkdir -p "$SRC" "$PREFIX"

    # zlib
    local ZVER=1.3.1
    if [ ! -d "$SRC/zlib-$ZVER" ]; then
        curl -L "https://zlib.net/zlib-$ZVER.tar.gz" -o /tmp/zlib.tar.gz
        tar -xzf /tmp/zlib.tar.gz -C "$SRC"
        rm /tmp/zlib.tar.gz
    fi
    ( cd "$SRC/zlib-$ZVER" && make distclean >/dev/null 2>&1 || true
        CC="$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang" \
        AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
        CFLAGS="-fPIE -fPIC -O2" LDFLAGS="-fPIE -pie" \
        ./configure --prefix="$PREFIX" --static --archs=-fPIC
        make -j"$(nproc)" && make install )

    # brotli
    local BRO_VER=1.1.0
    if [ ! -d "$SRC/brotli-$BRO_VER" ]; then
        curl -L "https://github.com/google/brotli/archive/refs/tags/v${BRO_VER}.tar.gz" -o /tmp/brotli.tar.gz
        tar -xzf /tmp/brotli.tar.gz -C "$SRC"
        rm /tmp/brotli.tar.gz
    fi
    ( cd "$SRC/brotli-$BRO_VER" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_SHARED_LIBS=OFF \
            -DBROTLI_BUILD_STATIC_LIBS=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_EXAMPLES=OFF ..
        make -j"$(nproc)" && make install )

    # OpenSSL
    local OPENSSL_VER=3.3.2
    if [ ! -d "$SRC/openssl-$OPENSSL_VER" ]; then
        curl -L "https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz" -o /tmp/openssl.tar.gz
        tar -xzf /tmp/openssl.tar.gz -C "$SRC"
        rm /tmp/openssl.tar.gz
    fi
    ( cd "$SRC/openssl-$OPENSSL_VER" && make distclean >/dev/null 2>&1 || true
        export ANDROID_NDK_HOME=$NDK ANDROID_NDK=$NDK PATH="$TOOLCHAIN/bin:$PATH" ANDROID_API=$API
        ./Configure android-$ABI --prefix=$PREFIX --openssldir=$PREFIX/ssl no-shared no-dso no-tests no-asm
        make -j"$(nproc)" && make install_sw )

    # expat
    local EXPAT_VER=2.6.4
    if [ ! -d "$SRC/expat-$EXPAT_VER" ]; then
        curl -L "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VER//./_}/expat-$EXPAT_VER.tar.gz" -o /tmp/expat.tar.gz
        tar -xzf /tmp/expat.tar.gz -C "$SRC"
        rm /tmp/expat.tar.gz
    fi
    ( cd "$SRC/expat-$EXPAT_VER" && make distclean >/dev/null 2>&1 || true
        ./buildconf.sh >/dev/null 2>&1 || true
        CC="$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang" \
        AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
        ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --enable-static --disable-shared \
            --without-examples --without-tests --without-docbook PKG_CONFIG=
        make -j"$(nproc)" && make install )

    # libxml2
    local XML2_VER=2.12.7
    if [ ! -d "$SRC/libxml2-$XML2_VER" ]; then
        curl -L "https://download.gnome.org/sources/libxml2/2.12/libxml2-$XML2_VER.tar.xz" -o /tmp/libxml2.tar.xz
        tar -xJf /tmp/libxml2.tar.xz -C "$SRC"
        rm /tmp/libxml2.tar.xz
    fi
    ( cd "$SRC/libxml2-$XML2_VER" && make distclean >/dev/null 2>&1 || true
        CC="$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang" \
        AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" STRIP="$TOOLCHAIN/bin/llvm-strip" \
        CFLAGS="-fPIE -fPIC -O2" LDFLAGS="-fPIE -pie" XML_SOCKLEN_T=socklen_t \
        ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --enable-static --disable-shared \
            --without-python --with-lzma=no --with-icu=no --with-zlib=yes --with-iconv=no \
            --without-debug --without-mem-debug --without-run-debug --with-threads=no
        sed -i 's/^#define XML_SOCKLEN_T .*/#define XML_SOCKLEN_T socklen_t/' config.h
        make -j"$(nproc)" && make install )
}

# Build render/text stack (libpng + freetype + harfbuzz).
build_android_render_libs() {
    local ABI=$1 API=$2 NDK=$3 PREFIX=$4 SRC=$5
    local TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

    mkdir -p "$SRC" "$PREFIX"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

    # libpng
    local PNG_VER=1.6.43
    if [ ! -d "$SRC/libpng-$PNG_VER" ]; then
        curl -L "https://download.sourceforge.net/libpng/libpng-$PNG_VER.tar.gz" -o /tmp/libpng.tar.gz
        tar -xzf /tmp/libpng.tar.gz -C "$SRC"
        rm /tmp/libpng.tar.gz
    fi
    ( cd "$SRC/libpng-$PNG_VER" && make distclean >/dev/null 2>&1 || true
        rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_PREFIX_PATH=$PREFIX \
            -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_DEBUG=OFF -DPNG_EXECUTABLES=OFF ..
        make -j"$(nproc)" && make install )

    # freetype
    local FT_VER=2.13.2
    if [ ! -d "$SRC/freetype-$FT_VER" ]; then
        curl -L "https://download.savannah.gnu.org/releases/freetype/freetype-$FT_VER.tar.gz" -o /tmp/freetype.tar.gz
        tar -xzf /tmp/freetype.tar.gz -C "$SRC"
        rm /tmp/freetype.tar.gz
    fi
    ( cd "$SRC/freetype-$FT_VER" && make distclean >/dev/null 2>&1 || true
        rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_PREFIX_PATH=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_HARFBUZZ=ON \
            -DFT_REQUIRE_BROTLI=ON -DFT_REQUIRE_PNG=ON -DFT_REQUIRE_ZLIB=ON \
            -DPNG_PNG_INCLUDE_DIR=$PREFIX/include -DPNG_LIBRARY=$PREFIX/lib/libpng16.a \
            -DZLIB_LIBRARY=$PREFIX/lib/libz.a -DZLIB_INCLUDE_DIR=$PREFIX/include \
            -DBROTLIDEC_INCLUDE_DIRS=$PREFIX/include \
            -DBROTLIDEC_LIBRARIES="$PREFIX/lib/libbrotlidec-static.a;$PREFIX/lib/libbrotlicommon-static.a" ..
        make -j"$(nproc)" && make install )

    # harfbuzz (CMake backend)
    local HB_VER=8.4.0
    if [ ! -d "$SRC/harfbuzz-$HB_VER" ]; then
        curl -L "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$HB_VER.tar.gz" -o /tmp/harfbuzz.tar.gz
        tar -xzf /tmp/harfbuzz.tar.gz -C "$SRC"
        rm /tmp/harfbuzz.tar.gz
    fi
    ( cd "$SRC/harfbuzz-$HB_VER" && make distclean >/dev/null 2>&1 || true
        rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_PREFIX_PATH=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DHB_BUILD_UTILS=OFF -DHB_BUILD_TESTS=OFF \
            -DHB_HAVE_FREETYPE=ON -DHB_HAVE_CAIRO=OFF -DHB_HAVE_ICU=OFF -DHB_HAVE_GLIB=OFF \
            -DFREETYPE_LIBRARY=$PREFIX/lib/libfreetype.a \
            -DFREETYPE_INCLUDE_DIRS=$PREFIX/include/freetype2 ..
        make -j"$(nproc)" && make install )
}

# Build the remaining multimedia stack required by LIBS_COMMON for Android.
build_android_media_libs() {
    local ABI=$1 API=$2 NDK=$3 PREFIX=$4 SRC=$5 TARGET_HOST=$6
    local TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

    mkdir -p "$SRC" "$PREFIX"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
    export PATH="$TOOLCHAIN/bin:$PATH"

    ensure_meson() {
        if command -v meson >/dev/null 2>&1; then
            return
        fi
        echo "--- Installing meson (pip) ---"
        python3 -m pip install --no-cache-dir --break-system-packages "meson>=1.3,<1.5"
    }

    ensure_gperf() {
        if command -v gperf >/dev/null 2>&1; then
            return
        fi
        echo "--- Installing gperf (apt) ---"
        apt-get update && apt-get install -y gperf && rm -rf /var/lib/apt/lists/*
    }

    fetch_src() {
        local name=$1 ver=$2 url=$3
        if [ -d "$SRC/${name}-${ver}" ]; then
            return
        fi

        local tarball="/tmp/${name}.tar"
        echo "--- Downloading $name $ver ---"
        rm -f "$tarball"
        if ! curl -fL --retry 3 --retry-delay 1 "$url" -o "$tarball"; then
            echo "[ERROR] Failed to download $name from $url" >&2
            return 1
        fi

        case "$url" in
            *.tar.gz|*.tgz) tar -xzf "$tarball" -C "$SRC" ;;
            *.tar.xz|*.txz) tar -xJf "$tarball" -C "$SRC" ;;
            *.tar.bz2) tar -xjf "$tarball" -C "$SRC" ;;
            *) echo "[WARN] Unknown format for $url" >&2 ;;
        esac
        rm -f "$tarball"
    }

    meson_cross_file() {
        local cpu_family cpu
        case "$ABI" in
            arm64-v8a|native) cpu_family="aarch64"; cpu="aarch64" ;;
            armeabi-v7a|arm|armv7-a|arm-v7n) cpu_family="arm"; cpu="armv7" ;;
            x86) cpu_family="x86"; cpu="i686" ;;
            x86_64) cpu_family="x86_64"; cpu="x86_64" ;;
            *)
                echo "[ERROR] Meson cross file does not support ABI: $ABI" >&2
                return 1
                ;;
        esac
        cat > /tmp/meson-${ABI}.ini <<EOF
[binaries]
c = '$CC'
ar = '$AR'
strip = '$STRIP'
pkgconfig = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = '$cpu_family'
cpu = '$cpu'
endian = 'little'
EOF
    }

    # libogg
    fetch_src "libogg" "1.3.5" "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz"
    ( cd "$SRC/libogg-1.3.5" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic
        make -j"$(nproc)" && make install )

    # libvorbis
    fetch_src "libvorbis" "1.3.7" "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
    ( cd "$SRC/libvorbis-1.3.7" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic
        make -j"$(nproc)" && make install )

    # opus
    fetch_src "opus" "1.4" "https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz"
    ( cd "$SRC/opus-1.4" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic --disable-extra-programs --disable-doc
        make -j"$(nproc)" && make install )

    # libmp3lame
    fetch_src "lame" "3.100" "https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
    ( cd "$SRC/lame-3.100" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic --disable-frontend
        make -j"$(nproc)" && make install )

    # twolame
    fetch_src "twolame" "0.4.0" "https://downloads.sourceforge.net/twolame/twolame-0.4.0.tar.gz"
    ( cd "$SRC/twolame-0.4.0" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic
        make -j"$(nproc)" && make install )

    # fribidi (meson)
    ensure_meson
    fetch_src "fribidi" "1.0.13" "https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz"
    meson_cross_file
    local FRIBIDI_BUILD="/tmp/fribidi-android-$ABI"
    ( cd "$SRC/fribidi-1.0.13" && rm -rf "$FRIBIDI_BUILD" && mkdir -p "$FRIBIDI_BUILD" && \
        ( meson setup "$FRIBIDI_BUILD" --prefix="$PREFIX" --buildtype=release --default-library=static \
            --cross-file /tmp/meson-${ABI}.ini -Ddocs=false -Dbin=false -Dtests=false \
            || { echo "[WARN] meson setup failed; wiping and retrying" >&2; \
                 rm -rf "$FRIBIDI_BUILD" && mkdir -p "$FRIBIDI_BUILD" && sleep 1 && \
                 meson setup "$FRIBIDI_BUILD" --wipe --prefix="$PREFIX" --buildtype=release --default-library=static \
                    --cross-file /tmp/meson-${ABI}.ini -Ddocs=false -Dbin=false -Dtests=false \
                 || { echo "[WARN] meson setup still failing; touching coredata and retrying" >&2; \
                      touch "$FRIBIDI_BUILD"/meson-private/coredata.dat 2>/dev/null || true; sleep 1; \
                      meson setup "$FRIBIDI_BUILD" --wipe --prefix="$PREFIX" --buildtype=release --default-library=static \
                        --cross-file /tmp/meson-${ABI}.ini -Ddocs=false -Dbin=false -Dtests=false; }; } ) && \
        { find "$FRIBIDI_BUILD" -maxdepth 2 -type f -exec touch {} + 2>/dev/null || true; } && \
        ninja -C "$FRIBIDI_BUILD" install )

    # fontconfig
    ensure_gperf
    fetch_src "fontconfig" "2.15.0" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.gz"
    ( cd "$SRC/fontconfig-2.15.0" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS -I$PREFIX/include" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            FREETYPE_LIBS="-L$PREFIX/lib -lfreetype -lbrotlidec -lbrotlicommon -lbrotlienc -lpng16 -lz" FREETYPE_CFLAGS="-I$PREFIX/include/freetype2" \
            EXPAT_LIBS="-L$PREFIX/lib -lexpat" EXPAT_CFLAGS="-I$PREFIX/include" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic \
                --with-expat=$PREFIX --disable-docs --disable-nls
        make -j"$(nproc)" && make install )

    # libass
    fetch_src "libass" "0.17.3" "https://github.com/libass/libass/releases/download/0.17.3/libass-0.17.3.tar.gz"
    ( cd "$SRC/libass-0.17.3" && make distclean >/dev/null 2>&1 || true
        CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS -I$PREFIX/include" LDFLAGS="$LDFLAGS -L$PREFIX/lib" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --disable-asm
        make -j"$(nproc)" && make install )

    # libvpx
    fetch_src "libvpx" "1.13.1" "https://github.com/webmproject/libvpx/archive/refs/tags/v1.13.1.tar.gz"
    local VPX_TARGET
    case "$ABI" in
        arm64-v8a) VPX_TARGET="arm64-android-gcc" ;;
        armeabi-v7a|arm|armv7-a|arm-v7n) VPX_TARGET="armv7-android-gcc" ;;
        x86) VPX_TARGET="x86-android-gcc" ;;
        x86_64) VPX_TARGET="x86_64-android-gcc" ;;
    esac
    ( cd "$SRC/libvpx-1.13.1" && make distclean >/dev/null 2>&1 || true
        ./configure --prefix="$PREFIX" --target=$VPX_TARGET --disable-examples --disable-tools --disable-unit-tests \
            --enable-pic --enable-static --disable-shared --disable-docs --disable-webm-io --disable-libyuv \
            --disable-runtime-cpu-detect
        make -j"$(nproc)" && make install )

    # libwebp
    fetch_src "libwebp" "1.3.2" "https://github.com/webmproject/libwebp/archive/refs/tags/v1.3.2.tar.gz"
    ( cd "$SRC/libwebp-1.3.2" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_PREFIX_PATH=$PREFIX -DBUILD_SHARED_LIBS=OFF \
            -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF \
            -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF ..
        make -j"$(nproc)" && make install )

    # libopenjpeg
    fetch_src "openjpeg" "2.5.2" "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.2.tar.gz"
    ( cd "$SRC/openjpeg-2.5.2" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_PKGCONFIG_FILES=ON -DBUILD_TESTING=OFF ..
        make -j"$(nproc)" && make install )

    # zimg (autotools)
    fetch_src "zimg" "3.0.5" "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.5.tar.gz"
    ( cd "$SRC/zimg-release-3.0.5" && make distclean >/dev/null 2>&1 || true
        ./autogen.sh
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" STRIP="$STRIP" \
            CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --disable-shared --enable-static --with-pic
        make -j"$(nproc)" && make install )

    # libsoxr
    fetch_src "soxr" "0.1.3" "https://downloads.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz"
    ( cd "$SRC/soxr-0.1.3-Source" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_C_FLAGS="$CFLAGS -Wno-c99-extensions -Wno-uninitialized -Wno-conditional-uninitialized" \
            -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DWITH_OPENMP=OFF ..
        make -j"$(nproc)" && make install )

    # libvidstab
    fetch_src "vid.stab" "1.1.1" "https://github.com/georgmartius/vid.stab/archive/refs/tags/v1.1.1.tar.gz"
    ( cd "$SRC/vid.stab-1.1.1" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DUSE_OMP=OFF ..
        make -j"$(nproc)" && make install )

    # libsrt
    fetch_src "srt" "1.5.3" "https://github.com/Haivision/srt/archive/refs/tags/v1.5.3.tar.gz"
    ( cd "$SRC/srt-1.5.3" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_C_FLAGS="$CFLAGS -Wno-deprecated-declarations" \
            -DCMAKE_CXX_FLAGS="$CFLAGS -Wno-deprecated-declarations" \
            -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DENABLE_TESTING=OFF \
            -DUSE_OPENSSL_PC=ON -DENABLE_C_DEPS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON ..
        make -j"$(nproc)" && make install )

    # libaom
    fetch_src "libaom" "3.9.0" "https://storage.googleapis.com/aom-releases/libaom-3.9.0.tar.gz"
    ( cd "$SRC/libaom-3.9.0" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && cd build-android-$ABI
        cmake -G"Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DENABLE_EXAMPLES=OFF \
            -DENABLE_NASM=OFF -DENABLE_CCACHE=OFF -DCONFIG_PIC=1 ..
        make -j"$(nproc)" && make install )

    # libdav1d
    ensure_meson
    fetch_src "dav1d" "1.4.2" "https://code.videolan.org/videolan/dav1d/-/archive/1.4.2/dav1d-1.4.2.tar.bz2"
    meson_cross_file
    ( cd "$SRC/dav1d-1.4.2" && rm -rf build-android-$ABI && mkdir -p build-android-$ABI && \
        ( meson setup build-android-$ABI --prefix="$PREFIX" --buildtype=release --default-library=static \
            --cross-file /tmp/meson-${ABI}.ini -Denable_tests=false -Denable_tools=false -Denable_examples=false \
            || { echo "[WARN] meson setup failed; wiping and retrying" >&2; \
                 rm -rf build-android-$ABI && mkdir -p build-android-$ABI && sleep 1 && \
                 meson setup build-android-$ABI --wipe --prefix="$PREFIX" --buildtype=release --default-library=static \
                    --cross-file /tmp/meson-${ABI}.ini -Denable_tests=false -Denable_tools=false -Denable_examples=false \
                 || { echo "[WARN] meson setup still failing; touching coredata and retrying" >&2; \
                      touch build-android-$ABI/meson-private/coredata.dat 2>/dev/null || true; sleep 1; \
                      meson setup build-android-$ABI --wipe --prefix="$PREFIX" --buildtype=release --default-library=static \
                        --cross-file /tmp/meson-${ABI}.ini -Denable_tests=false -Denable_tools=false -Denable_examples=false; }; } ) && \
        touch build-android-$ABI/meson-private/coredata.dat && \
        ninja -C build-android-$ABI install )
}

function build_android {
    echo ">>> Iniciando compilacion para ANDROID (ARM64 - API 24) <<<"

    load_config
    ensure_sources

    NDK="${NDK:-/opt/android-ndk}"
    if [ ! -d "$NDK" ]; then
        echo "ERROR: No se encontro el NDK en $NDK. Revisa tu Dockerfile."
        exit 1
    fi

    API=24
    TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
    local libs feature_flags extra_version_flag
    libs=$(collect_target_libs "android")
    extra_version_flag=$(ffmpeg_extra_version_flag)

    mkdir -p /output

    for ABI in ${ANDROID_ABIS:-"arm64-v8a armeabi-v7a x86 x86_64"}; do
        echo "--- ABI $ABI ---"

        arch_extra_flags=""
        stl_triple=""
        case "$ABI" in
            arm64-v8a)
                TARGET_HOST="aarch64-linux-android"
                ARCH="aarch64"
                CPU=""
                stl_triple="aarch64-linux-android"
                ;;
            armeabi-v7a|arm|armv7-a|arm-v7n)
                TARGET_HOST="armv7a-linux-androideabi"
                ARCH="arm"
                CPU="armv7-a"
                stl_triple="arm-linux-androideabi"
                ;;
            x86)
                TARGET_HOST="i686-linux-android"
                ARCH="x86"
                CPU=""
                arch_extra_flags="--disable-x86asm --disable-asm"
                stl_triple="i686-linux-android"
                ;;
            x86_64)
                TARGET_HOST="x86_64-linux-android"
                ARCH="x86_64"
                CPU=""
                arch_extra_flags="--disable-x86asm"
                stl_triple="x86_64-linux-android"
                ;;
            native)
                TARGET_HOST="aarch64-linux-android"
                ARCH="aarch64"
                CPU=""
                stl_triple="aarch64-linux-android"
                ;;
            *)
                echo "[WARN] ABI no soportado: $ABI" >&2
                continue
                ;;
        esac

        export AR=$TOOLCHAIN/bin/llvm-ar
        export CC=$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang
        export CXX=$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang++
        # Use the compiler driver as linker so libvpx (and others) get correct target flags.
        export LD=$CC
        export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        export STRIP=$TOOLCHAIN/bin/llvm-strip

        export PREFIX="/build/dist/android/$ABI"
        export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
        export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
        # Suppress noisy upstream deprecation/const-conversion warnings for cleaner Android logs.
        export CFLAGS="-fPIE -fPIC -std=gnu11 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations -Wno-implicit-const-int-float-conversion -Wno-implicit-int-float-conversion -Wno-unused-but-set-variable -Wno-unknown-pragmas -Wno-maybe-uninitialized -I$PREFIX/include"
        export CPPFLAGS="-I$PREFIX/include"
        libcxx_dir="$TOOLCHAIN/sysroot/usr/lib/${stl_triple}/${API}"
        [ -d "$libcxx_dir" ] || libcxx_dir="$TOOLCHAIN/sysroot/usr/lib/${stl_triple}"

        export LDFLAGS="-fPIE -pie -L$PREFIX/lib -L$libcxx_dir -static-libstdc++ -static-libgcc"

        mkdir -p "$PREFIX" "$PKG_CONFIG_PATH"

        build_android_base_libs "$ABI" "$API" "$NDK" "$PREFIX" "$SRC_ROOT"
        build_android_render_libs "$ABI" "$API" "$NDK" "$PREFIX" "$SRC_ROOT"
        build_android_media_libs "$ABI" "$API" "$NDK" "$PREFIX" "$SRC_ROOT" "$TARGET_HOST"

        # Re-evaluate feature flags now that pkg-config files exist for this ABI.
        feature_flags=$(ffmpeg_feature_flags "android" "$libs")

        build_x264 "$TARGET_HOST" "$PREFIX" "--cross-prefix=$TOOLCHAIN/bin/llvm- --disable-asm --enable-pic --disable-cli"

        echo "--- Compilando FFmpeg (Android $ABI) ---"
        cd /build/sources/ffmpeg-$FFMPEG_VER

        make distclean || true

        ./configure \
            --prefix=$PREFIX \
            --target-os=android \
            --arch=$ARCH \
            ${CPU:+--cpu=$CPU} \
            --cc=$CC \
            --cxx=$CXX \
            --ar=$AR \
            --ranlib=$RANLIB \
            --strip=$STRIP \
            --enable-cross-compile \
            --pkg-config-flags="--static" \
            --extra-libs="-lm -Wl,-Bstatic -lc++_static -Wl,-Bdynamic -latomic" \
            --enable-static \
            --disable-shared \
            --enable-gpl \
            --enable-version3 \
            --disable-debug \
            --disable-doc \
            --disable-ffplay \
            --enable-neon \
            $arch_extra_flags \
            ${extra_version_flag:+$extra_version_flag} \
            $feature_flags

        # Force static libc++ so ffmpeg does not depend on libc++_shared.so
        sed -i 's/-lstdc++/-lc++_static -lc++abi -lunwind/g; s/-lc++ /-lc++_static /g; s/-lc++$/-lc++_static/g' ffbuild/config.mak

        make -j$(nproc)

        output_dir="/output/${FFMPEG_VER}/android/$ABI"
        mkdir -p "$output_dir"
        cp ffmpeg "$output_dir/ffmpeg"
        echo "Hecho. Para probarlo en Android usa: adb push $output_dir/ffmpeg /data/local/tmp/"
    done
}
