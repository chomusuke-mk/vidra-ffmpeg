# Vidra FFmpeg

Este proyecto compila FFmpeg y FFprobe en un contenedor Docker, junto a todas las dependencias necesarias.

## Para recrear la imagen de Docker

```sh
docker compose --progress=plain build
```

## Para ver los archivos como están en el contenedor

- Los archivos descomprimidos en temp/source
- Archivos parcheados en temp/patched

```sh
./view_files.sh
```

## Para compilar FFmpeg y FFprobe

```sh
docker compose run --rm vidra-ffmpeg OS ARCH
```

### Supported architectures

| OS      | ARCH        |
| ------- | ----------- |
| linux   | x86_64      |
| windows | x86_64      |
| android | arm64-v8a   |
| android | armeabi-v7a |
| android | x86         |
| android | x86_64      |

## Archivos compilados

dist/linux-x86_64/ffmpeg ffprobe
dist/windows-x86_64/ffmpeg.exe ffprobe.exe
dist/android-arm64-v8a/ffmpeg ffprobe
dist/android-armeabi-v7a/ffmpeg ffprobe
dist/android-x86/ffmpeg ffprobe
dist/android-x86_64/ffmpeg ffprobe
