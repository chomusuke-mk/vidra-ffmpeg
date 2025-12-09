# Plan de integración Android: habilitar `LIBS_COMMON`

Objetivo: construir binarios FFmpeg Android (ABI x86_64, API 24) con todas las libs en `LIBS_COMMON` estáticas y autodetectables vía pkg-config.

## Entorno base

- NDK: `/opt/android-ndk`, toolchain: `${NDK}/toolchains/llvm/prebuilt/linux-x86_64`.
- ABI: x86_64 (ajustar `ANDROID_ABIS` si luego se amplía).
- Prefijo de sysroot de terceros: `/build/dist/android/x86_64`.
- Exportar (ejemplo):
  - `export AR=${TOOLCHAIN}/bin/llvm-ar`
  - `export CC=${TOOLCHAIN}/bin/x86_64-linux-android24-clang`
  - `export CXX=${TOOLCHAIN}/bin/x86_64-linux-android24-clang++`
  - `export LD=${TOOLCHAIN}/bin/ld`
  - `export RANLIB=${TOOLCHAIN}/bin/llvm-ranlib`
  - `export STRIP=${TOOLCHAIN}/bin/llvm-strip`
  - `export PREFIX=/build/dist/android/x86_64`
  - `export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig`
  - `export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH`
  - `export CFLAGS="-fPIE -fPIC -D_FORTIFY_SOURCE=2"
  - `export LDFLAGS="-fPIE -pie"

## Regla general de build

- Autotools: `./configure --host=x86_64-linux-android --prefix=$PREFIX --enable-static --disable-shared --with-pic PKG_CONFIG=$TOOLCHAIN/bin/llvm-pkg-config`
- CMake: `-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=24 -DANDROID_STL=c++_static -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$PREFIX`
- Meson (si aplica): `--cross-file` con same triplet y `default_library=static`.
- Asegurar instalación de headers `.pc` en `$PREFIX/lib/pkgconfig`.

## Orden recomendado de librerías y flags clave

1. zlib (base para varias): autotools; sin shared.
2. brotli (opcional para freetype): `-DBUILD_SHARED_LIBS=OFF`.
3. openssl (ó boringssl si se prefiere): `./Configure android-x86_64 no-shared no-tests --prefix=$PREFIX`.
4. expat (necesario para fontconfig): CMake static.
5. libxml2: `./configure --host=... --with-python=no --with-lzma=no --with-icu=no --enable-static --disable-shared`.
6. freetype: `-DZLIB_INCLUDE_DIR=$PREFIX/include -DZLIB_LIBRARY=$PREFIX/lib/libz.a -DBUILD_SHARED_LIBS=OFF -DFT_WITH_BROTLI=ON/OFF`.
7. harfbuzz: `-DHB_HAVE_FREETYPE=ON -DHB_BUILD_UTILS=OFF -DHB_HAVE_OT=ON -DBUILD_SHARED_LIBS=OFF`.
8. fribidi: autotools static.
9. fontconfig: `PKG_CONFIG_PATH` con expat/freetype/libxml2; `--enable-static --disable-shared`.
10. libass: `--enable-static --disable-shared` (usa freetype, harfbuzz, fribidi, fontconfig).
11. libmp3lame: autotools static; `--disable-shared`.
12. opus: `./configure --host=... --enable-static --disable-shared --disable-extra-programs`.
13. libvorbis + libogg: construir primero libogg, luego libvorbis static.
14. twolame: autotools static.
15. libaom: CMake `-DENABLE_SHARED=0 -DENABLE_TESTS=0 -DENABLE_NASM=0` (evitar asm para Android x86_64 si da problemas; si se quiere asm, añadir `-DAOM_TARGET_CPU=x86_64` con toolchain).
16. libdav1d: Meson `--default-library=static --enable_asm=false` (o true si se valida) `--cross-file` NDK.
17. libvpx: `--target=x86_64-android-gcc --disable-shared --enable-static --disable-tools --disable-examples --disable-docs --disable-unit-tests --disable-avx512`.
18. libwebp: `-DBUILD_SHARED_LIBS=OFF -DWEBP_ENABLE_SIMD=OFF|ON` según estabilidad en NDK.
19. libopenjpeg: `-DBUILD_SHARED_LIBS=OFF -DBUILD_PKGCONFIG_FILES=ON`.
20. zimg: `-DBUILD_SHARED_LIBS=OFF -DZIMG_FILTERS=ON` (puede requerir desactivar asm si hay reloc issues).
21. libsoxr: `-DBUILD_SHARED_LIBS=OFF -DWITH_OPENMP=OFF`.
22. fftw3 (para librubberband): `./configure --host=... --enable-static --disable-shared --with-pic --enable-sse2 --disable-fortran`.
23. librubberband: `-DBUILD_SHARED_LIBS=OFF -DRUBBERBAND_BUILD_TOOLS=OFF -DRUBBERBAND_INSTALL_PKGCONFIG=ON -DFFT_PKGCONFIG=fftw3`.
24. libvidstab: `cmake -DBUILD_SHARED_LIBS=OFF -DUSE_OMP=OFF`.
25. libsrt: `-DENABLE_SHARED=OFF -DENABLE_C_DEPS=ON -DUSE_ENCLIB=openssl -DENABLE_ENCRYPTION=ON`.
26. x264 (ya integrado): `--host=x86_64-linux-android --enable-static --disable-cli --disable-asm --enable-pic`.

## FFmpeg configure (x86_64 Android)

Usar tras instalar los `.pc` en `$PREFIX`:

```
./configure \
  --prefix=$PREFIX \
  --target-os=android \
  --arch=x86_64 \
  --cc=$CC --cxx=$CXX --ar=$AR --ranlib=$RANLIB --strip=$STRIP \
  --enable-cross-compile \
  --pkg-config-flags="--static" \
  --enable-static --disable-shared \
  --enable-gpl --enable-version3 \
  --disable-debug --disable-doc --disable-ffplay \
  --enable-neon --disable-x86asm \
  --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" \
  $(ffmpeg_feature_flags android "${LIBS_COMMON} ${LIBS_ANDROID}")
```

Si se valida asm segura para x86_64, se puede quitar `--disable-x86asm`.

## Verificación

- Comprobar que `pkg-config --exists <lib>` funciona en `$PREFIX` antes de `./configure` FFmpeg.
- Revisar `ffmpeg -buildconf` en la salida final para confirmar libs habilitadas.
- Probar en dispositivo/emulador: `adb push /output/7.1.3/android/x86_64/ffmpeg /data/local/tmp/ && adb shell /data/local/tmp/ffmpeg -codecs`.

## Notas de riesgo

- Algunas libs requieren parches menores para cross-compile (rpath, tests). Deshabilitar tests/examples para acelerar.
- Mantener `PKG_CONFIG_PATH`/`PKG_CONFIG_LIBDIR` apuntando solo al prefix Android evita mezclar artefactos host.
- Si una lib falla por asm no-PIC, reintentar con asm desactivado.
