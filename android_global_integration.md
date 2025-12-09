# Guía global de integración Android (todas las `LIBS_COMMON`)

Meta: definir un flujo unificado para portar todas las libs de `LIBS_COMMON` (y complementos) a Android, reutilizando el patrón ya validado con x264. La idea es evitar planes por-lib separados y tener un pipeline repetible para cualquier ABI/versión.

## Principios clave

- Toolchain único por ABI/API: usar `${NDK}/toolchains/llvm/prebuilt/linux-x86_64` con triplets `${TRIPLE}${API}` (ej. `x86_64-linux-android24-clang`).
- Artefactos aislados: `PREFIX=/build/dist/android/${ABI}` con `PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig` y `PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH` para no mezclar host.
- Estática y PIC: `--enable-static --disable-shared --with-pic` (Autotools) o `-DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON` (CMake); `default_library=static` (Meson).
- Sin tests/herramientas: desactivar samples/tests/docs para acelerar y evitar dependencias extra.
- ASM opcional: deshabilitar asm si hay relocaciones no-PIC; habilitar sólo tras validar en cada ABI.

## Variables estándar (plantilla)

```
export NDK=/opt/android-ndk
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export API=24
export ABI=x86_64                  # cambiar por arm64-v8a/armeabi-v7a/x86
export TRIPLE=x86_64-linux-android # adaptar por ABI
export PREFIX=/build/dist/android/$ABI
export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/${TRIPLE}${API}-clang
export CXX=$TOOLCHAIN/bin/${TRIPLE}${API}-clang++
export LD=$TOOLCHAIN/bin/ld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH
export CFLAGS="-fPIE -fPIC -D_FORTIFY_SOURCE=2"
export LDFLAGS="-fPIE -pie"
```

## Patrones por build system

- **Autotools**: `./configure --host=$TRIPLE --prefix=$PREFIX --enable-static --disable-shared --with-pic PKG_CONFIG=$TOOLCHAIN/bin/llvm-pkg-config`
- **CMake**: `-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=$ABI -DANDROID_PLATFORM=$API -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX=$PREFIX -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON`
- **Meson**: cross-file apuntando al triplet; `-Ddefault_library=static -Db_pie=true -Db_ndebug=true -Db_lto=false` y `--pkg-config-path=$PKG_CONFIG_PATH`.

## Checklist de librerías (`LIBS_COMMON` + deps)

- Núcleo base: `zlib`, `brotli` (opcional), `openssl`/`boringssl`, `expat`, `libxml2`.
- Render/texto: `freetype`, `harfbuzz`, `fribidi`, `fontconfig`, `libass`.
- Audio: `libmp3lame`, `opus`, `libvorbis` (+ `libogg`), `twolame`.
- Vídeo/IMF: `libaom`, `libdav1d`, `libvpx`, `libwebp`, `libopenjpeg`, `zimg`.
- DSP: `libsoxr`, `fftw3`, `librubberband`.
- Otros: `libvidstab`, `libsrt`.
- Ya integrado: `x264` (patrón base de referencia: host triplet, static, PIC, sin CLI/ASM si rompe).

## Progreso actual

- zlib 1.3.1 para `x86_64` construido estatico/PIC en `PREFIX=/build/dist/android/x86_64` usando API 24 y toolchain NDK clang.
- brotli 1.1.0 para `x86_64` construido estatico/PIC via CMake toolchain NDK (API 24) en `PREFIX=/build/dist/android/x86_64`.
- openssl 3.3.2 para `x86_64` (API 24) construido estatico (`libssl.a`, `libcrypto.a`) sin shared/DSO/tests en `PREFIX=/build/dist/android/x86_64`.
- expat 2.6.4 para `x86_64` (API 24) construido estatico, sin tests/ejemplos, instalado en `PREFIX=/build/dist/android/x86_64`.
- libxml2 2.12.7 para `x86_64` (API 24) construido estatico, sin python/lzma/icu/iconv, instalado en `PREFIX=/build/dist/android/x86_64`.

## Estrategia de orden

1. Compilar zlib → brotli → openssl/boringssl → expat → libxml2 (desactivar python/lzma/icu).
2. Freetype (consumiendo zlib/brotli) → harfbuzz → fribidi → fontconfig → libass.
3. Ogg/Vorbis/Opus/MP3/Twolame (audio).
4. Códecs vídeo: aom, dav1d, vpx, webp, openjpeg, zimg (desactivar asm si hay relocaciones).
5. DSP: fftw3 (sin fortran) → libsoxr (sin openmp) → librubberband.
6. Miscelánea: libvidstab, libsrt (con openssl), x264 ya está.

## Reglas para soportar múltiples ABIs/APIs

- Iterar por `ANDROID_ABIS="arm64-v8a armeabi-v7a x86_64 x86"`; exportar TRIPLE/CC/PKG paths por ABI; reutilizar las mismas fuentes haciendo `make distclean` o builds fuera-de-árbol por ABI.
- Si alguna lib falla en asm para ARM o x86, añadir flags de desactivación (`-DENABLE_ASM=0`, `--disable-asm`, `--disable-x86asm`) sólo para ese ABI.
- Mantener un cache de descargas en `/build/sources` y outputs segregados en `/build/dist/android/$ABI`.

### Reutilizar fuentes entre ABIs (evitar recompilar descargas)

- Montar un directorio del host como cache común de fuentes (ej. bind `./sources_host_cache` → `/build/sources`) en `docker compose` para que las descargas se compartan entre runs y ABIs.
- Estandarizar `SRC=/build/sources` en todos los scripts Android; solo limpiar con `make distclean` por ABI en cada árbol (`zlib`, `brotli`, etc.) en lugar de borrar el directorio.
- Opcional: añadir a `ensure_sources` la descarga de bases (`zlib`, `brotli`, `openssl/boringssl`, `expat`, `libxml2`) en `$SRC` para que queden versionadas/caché única similar a x264/FFmpeg.

## Hooks/patching

- Deshabilitar tests/bench/examples (evita dependencias host y reduce tiempo).
- Parches comunes: quitar `-Werror`, forzar `-fPIC`, evitar `rpath` host, arreglar detección de `clock_gettime` usando NDK.
- Si una lib exige `pkg-config` host, exportar `PKG_CONFIG=$TOOLCHAIN/bin/llvm-pkg-config` o empaquetar un `.pc` mínimo a mano en `$PREFIX/lib/pkgconfig`.

## FFmpeg final

Usar `ffmpeg_feature_flags android "${LIBS_COMMON} ${LIBS_ANDROID}"` con `PKG_CONFIG_PATH` apuntando al prefix por ABI. Si se valida asm en x86_64/arm64, se puede quitar `--disable-x86asm`/`--disable-asm`; mantenerlo en x86/armeabi-v7a si hay relocaciones no-PIC.

## Verificación rápida

- `pkg-config --exists <lib>` antes de `./configure`.
- `readelf -h $PREFIX/lib/*.a` para confirmar `Machine` correcta por ABI.
- `ffmpeg -buildconf` en binario final; `adb push ... && adb shell ./ffmpeg -codecs`.

## Riesgos y mitigaciones

- ASM no-PIC: desactivar asm o usar toolchain flags `-fPIC`; en libvpx/libaom/libdav1d probar `--disable-asm` por ABI.
- Mezcla host/target: siempre limpiar (`make distclean`) y aislar `PKG_CONFIG_PATH` por ABI.
- Dependencias transitivas faltantes: revisar `.pc` y logs de `pkg-config --cflags --libs`.
