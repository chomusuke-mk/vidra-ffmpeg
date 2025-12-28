docker compose run --rm ffmpeg-builder linux
docker compose run --rm ffmpeg-builder windows
docker compose run --rm ffmpeg-builder android

# Vidra FFmpeg builder

Entorno Docker para compilar FFmpeg estático en Linux (x86_64), Windows (x86_64 via MinGW-w64) y Android (ABI seleccionable). Usa la configuración de `config.sh` para fijar versión y librerías por sistema.

## Requisitos

- Docker y Docker Compose.
- Espacio para NDK (~2 GB) y fuentes cacheadas en `./sources`.
- Conexion en el primer uso para descargar NDK, FFmpeg y x264.

## Configuración (`config.sh`)

Variables principales (ejemplo por defecto):

```bash
FFMPEG_VERSION=7.1.3
EXTRA_VERSION="vidra_build-chomusuke.dev"

LIBS_COMMON="iconv zlib libxml2 fontconfig harfbuzz freetype fribidi libass libaribcaption libaribb24 libaom libdav1d libdavs2 libuavs3d librav1e libsvtav1 libvpx libwebp libx264 libx265 libxavs2 libxvid libtheora libopenh264 libvvenc libmp3lame libopus libvorbis libtwolame libgme libspeex libgsm libssh libsrt librist libzmq libvmaf libplacebo libzimg libvidstab librubberband libsoxr chromaprint frei0r libsnappy libopenjpeg whisper"

# Desktop-only multimedia extras (no Android): bluray/DVD/teletexto/SDL
LIBS_LINUX="vaapi vulkan libshaderc opencl libvpl nvcodec libbluray libdvdnav libdvdread libzvbi sdl2"
LIBS_WINDOWS="dxva2 d3d11va vulkan libshaderc opencl schannel gmp amf libbluray libdvdnav libdvdread libzvbi sdl2"
LIBS_ANDROID="vulkan opencl jni mediacodec enable-neon"
ANDROID_ABI="arm64-v8a"  # elige uno: armeabi-v7a | arm64-v8a | x86 | x86_64
```

- `LIBS_*` controla librerías/flags; las específicas por sistema se usan para aceleración GPU (nvenc/vaapi/amf/mediacodec, etc.). Si una dependencia no está presente, se avisa y se omite.
- Cambia `FFMPEG_VERSION` para elegir la versión a descargar/compilar.

## Construir la imagen base

```bash
docker compose build               # usa ANDROID_NDK_VERSION=r27b por defecto
# o define otra version del NDK
# docker compose build --build-arg ANDROID_NDK_VERSION=r26d
```

## Compilar FFmpeg

Salidas en `./output/<version>/<sistema>/<abi>/` (para Linux/Windows el abi es el sistema en si).

```bash
# Linux estatico x86_64
docker compose run --rm ffmpeg-builder linux
# Windows estatico x86_64 (exe)
docker compose run --rm ffmpeg-builder windows
# Android (usa ANDROID_ABI de config.sh)
docker compose run --rm ffmpeg-builder android
```

## Limpieza rapida

```bash
rm -rf ./output/* ./sources/*
```

## Personalizar versiones y librerias

Edita `config.sh` (versión, librerías por sistema y ABI de Android) y reconstruye la imagen para regenerar dependencias/NDK si hace falta.

## Licencia

- Scripts y Dockerfiles de este repo: MIT (ver `LICENSE`).
- Binarios/resultados generados: se construyen con `--enable-gpl --enable-version3` y librerías GPL/GPLv3+, por lo que deben distribuirse bajo GPLv3 o compatible. No se incluyen componentes nonfree.
