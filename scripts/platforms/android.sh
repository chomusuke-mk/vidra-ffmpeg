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
        *) echo "[WARN] ABI base libs no soportado: $ABI" >&2; return 1;;
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
            export ANDROID_NDK_HOME=$NDK ANDROID_NDK=$NDK PATH="$TOOLCHAIN/bin:$PATH"
            ./Configure android-$ABI -D__ANDROID_API__=$API --prefix=$PREFIX --openssldir=$PREFIX/ssl no-shared no-dso no-tests no-asm
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
            CFLAGS="-fPIE -fPIC -O2" LDFLAGS="-fPIE -pie" \
            ./configure --host=${TARGET_HOST} --prefix="$PREFIX" --enable-static --disable-shared \
                --without-python --with-lzma=no --with-icu=no --with-zlib=yes --with-iconv=no \
                --without-debug --without-mem-debug --without-run-debug --with-threads=no
            make -j"$(nproc)" && make install )
}

# Build render/text stack (libpng + freetype + harfbuzz). Fontconfig/libass follow once validated per ABI.
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

function build_android {
    echo ">>> Iniciando compilación para ANDROID (ARM64 - API 24) <<<"

    load_config
    ensure_sources

    NDK="${NDK:-/opt/android-ndk}"
    if [ ! -d "$NDK" ]; then
        echo "ERROR: No se encontró el NDK en $NDK. Revisa tu Dockerfile."
        exit 1
    fi

    API=24
    TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
    local libs feature_flags extra_version_flag
    libs=$(collect_target_libs "android")
    feature_flags=$(ffmpeg_feature_flags "android" "$libs")
    extra_version_flag=$(ffmpeg_extra_version_flag)

    mkdir -p /output

    for ABI in ${ANDROID_ABIS:-"arm64-v8a armeabi-v7a x86 x86_64"}; do
        echo "--- ABI $ABI ---"

        arch_extra_flags=""
        case "$ABI" in
            arm64-v8a)
                TARGET_HOST="aarch64-linux-android"
                ARCH="aarch64"
                CPU=""
                ;;
            armeabi-v7a|arm|armv7-a|arm-v7n)
                TARGET_HOST="armv7a-linux-androideabi"
                ARCH="arm"
                CPU="armv7-a"
                ;;
            x86)
                TARGET_HOST="i686-linux-android"
                ARCH="x86"
                CPU=""
                arch_extra_flags="--disable-x86asm --disable-asm"
                ;;
            x86_64)
                TARGET_HOST="x86_64-linux-android"
                ARCH="x86_64"
                CPU=""
                arch_extra_flags="--disable-x86asm"
                ;;
            native)
                TARGET_HOST="aarch64-linux-android"
                ARCH="aarch64"
                CPU=""
                ;;
            *)
                echo "[WARN] ABI no soportado: $ABI" >&2
                continue
                ;;
        esac

        export AR=$TOOLCHAIN/bin/llvm-ar
        export CC=$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang
        export CXX=$TOOLCHAIN/bin/${TARGET_HOST}${API}-clang++
        export LD=$TOOLCHAIN/bin/ld
        export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
        export STRIP=$TOOLCHAIN/bin/llvm-strip

        export PREFIX="/build/dist/android/$ABI"
        export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
        # Suppress noisy upstream deprecation/const-conversion warnings for cleaner Android logs.
        export CFLAGS="-fPIE -fPIC -Wno-deprecated-declarations -Wno-implicit-const-int-float-conversion -Wno-implicit-int-float-conversion -Wno-unused-but-set-variable"
        export LDFLAGS="-fPIE -pie"

        mkdir -p "$PREFIX" "$PKG_CONFIG_PATH"

        # Build base dependencies for this ABI so compose users don't compile manually.
        build_android_base_libs "$ABI" "$API" "$NDK" "$PREFIX" "$SRC_ROOT"
        build_android_render_libs "$ABI" "$API" "$NDK" "$PREFIX" "$SRC_ROOT"

        build_x264 "$TARGET_HOST" "$PREFIX" "--cross-prefix=$TOOLCHAIN/bin/llvm- --disable-asm --enable-pic --disable-cli"

        echo "--- Compilando FFmpeg (Android $ABI) ---"
        cd /build/sources/ffmpeg-$FFMPEG_VER

        # Limpia restos de builds anteriores (e.g. COFF de x86_64) antes de reconfigurar
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

        make -j$(nproc)

        output_dir="/output/${FFMPEG_VER}/android/$ABI"
        mkdir -p "$output_dir"
        cp ffmpeg "$output_dir/ffmpeg"
        echo "Hecho. Para probarlo en Android usa: adb push $output_dir/ffmpeg /data/local/tmp/"
    done
}