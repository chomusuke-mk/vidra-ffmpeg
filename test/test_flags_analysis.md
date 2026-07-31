# Análisis de Flags y Cobertura de Tests

## Flags por Plataforma

| Flag                         | Linux | Windows       | Android | Test Actual en `test_ffmpeg.py` | Propuesta de Test                |
| ---------------------------- | ----- | ------------- | ------- | ------------------------------- | -------------------------------- |
| `--enable-iconv`             | Sí    | Sí            | Sí      | No (Implícito)                  | -                                |
| `--enable-zlib`              | Sí    | Sí            | Sí      | No (Implícito)                  | -                                |
| `--enable-libxml2`           | Sí    | Sí            | Sí      | No                              | Test `dash` muxer                |
| `--enable-libsoxr`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-openssl`           | Sí    | No (schannel) | No      | No                              | Test protocolo `tls`             |
| `--enable-libvmaf`           | Sí    | Sí            | Sí      | No                              | Test filtro `libvmaf`            |
| `--enable-fontconfig`        | Sí    | Sí            | Sí      | No (Implícito en freetype)      | -                                |
| `--enable-libharfbuzz`       | Sí    | Sí            | Sí      | No (Implícito en freetype)      | -                                |
| `--enable-libfreetype`       | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libfribidi`        | Sí    | Sí            | Sí      | No (Implícito en freetype)      | -                                |
| `--enable-vulkan`            | Sí    | Sí            | Sí      | Sí                              | (Ya existe pero mejoraremos)     |
| `--enable-libvorbis`         | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libxcb`            | Sí    | No            | No      | No                              | Específico de captura X11        |
| `--enable-xlib`              | Sí    | No            | No      | No                              | Específico de captura X11        |
| `--enable-libpulse`          | Sí    | No            | No      | No                              | Requiere demonio PulseAudio      |
| `--enable-gmp`               | Sí    | Sí            | Sí      | No (Implícito)                  | -                                |
| `--enable-lzma`              | Sí    | Sí            | Sí      | No (Implícito)                  | -                                |
| `--enable-liblcevc-dec`      | Sí    | Sí            | Sí      | No                              | Difícil sin archivo LCEVC        |
| `--enable-opencl`            | Sí    | Sí            | No      | Sí                              | -                                |
| `--enable-amf`               | Sí    | Sí            | No      | Sí                              | -                                |
| `--enable-libaom`            | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libaribb24`        | Sí    | Sí            | Sí      | No                              | Difícil sin stream ARIB          |
| `--enable-chromaprint`       | Sí    | Sí            | Sí      | No                              | Test filtro `chromaprint`        |
| `--enable-libdav1d`          | Sí    | Sí            | Sí      | No                              | Requiere archivo AV1             |
| `--enable-libdavs2`          | Sí    | Sí            | Sí      | No                              | Requiere archivo AVS2            |
| `--enable-libdvdread`        | Sí    | Sí            | Sí      | No                              | Requiere estructura DVD          |
| `--enable-libdvdnav`         | Sí    | Sí            | Sí      | No                              | Requiere estructura DVD          |
| `--enable-ffnvcodec`         | Sí    | Sí            | No      | Sí                              | -                                |
| `--enable-cuda-llvm`         | Sí    | Sí            | No      | No (Implícito en nvenc)         | -                                |
| `--enable-frei0r`            | Sí    | Sí            | Sí      | No                              | Requiere plugins frei0r          |
| `--enable-libgme`            | Sí    | Sí            | Sí      | No                              | Requiere archivo música juego    |
| `--enable-libkvazaar`        | Sí    | Sí            | Sí      | No                              | Test encoder `libkvazaar`        |
| `--enable-libaribcaption`    | Sí    | Sí            | Sí      | No                              | Difícil sin stream ARIB          |
| `--enable-libass`            | Sí    | Sí            | Sí      | No                              | Test filtro `ass` (crear .ass)   |
| `--enable-libbluray`         | Sí    | Sí            | Sí      | No                              | Requiere estructura Bluray       |
| `--enable-libjxl`            | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libmp3lame`        | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libopus`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libplacebo`        | Sí    | Sí            | Sí      | No                              | Test filtro `libplacebo`         |
| `--enable-librist`           | Sí    | Sí            | Sí      | No                              | Requiere server RIST             |
| `--enable-libssh`            | Sí    | Sí            | Sí      | No                              | Requiere server SSH/SFTP         |
| `--enable-libtheora`         | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libvpx`            | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libwebp`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libzmq`            | Sí    | Sí            | Sí      | No                              | Requiere server ZMQ              |
| `--enable-lv2`               | Sí    | Sí            | Sí      | No                              | Requiere plugins LV2             |
| `--enable-libvpl`            | Sí    | Sí            | Sí      | No                              | Test encoder `h264_qsv`          |
| `--enable-openal`            | Sí    | Sí            | Sí      | No                              | Requiere HW OpenAL               |
| `--enable-liboapv`           | Sí    | Sí            | Sí      | No                              | Test encoder `liboapv`           |
| `--enable-libopencore-amrnb` | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libopencore-amrwb` | Sí    | Sí            | Sí      | No                              | Test encoder `libopencore_amrwb` |
| `--enable-libopenh264`       | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libopenjpeg`       | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libopenmpt`        | Sí    | Sí            | Sí      | No                              | Requiere archivo Tracker         |
| `--enable-librav1e`          | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-librubberband`     | Sí    | Sí            | Sí      | No                              | Test filtro `rubberband`         |
| `--enable-schannel`          | No    | Sí            | No      | No (Implícito en TLS Windows)   | -                                |
| `--enable-sdl2`              | No    | Sí            | Sí      | No                              | Implícito para ffplay            |
| `--enable-libsnappy`         | Sí    | Sí            | Sí      | No                              | Implícito en formatos            |
| `--enable-libsrt`            | Sí    | Sí            | Sí      | No                              | Requiere server SRT              |
| `--enable-libsvtav1`         | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libtwolame`        | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libuavs3d`         | Sí    | Sí            | Sí      | No                              | Requiere archivo AVS3            |
| `--enable-libdrm`            | Sí    | No            | No      | No (Implícito en vaapi)         | -                                |
| `--enable-vaapi`             | Sí    | No            | No      | Sí                              | -                                |
| `--enable-libvidstab`        | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libvvenc`          | Sí    | No            | Sí      | No                              | Test encoder `libvvenc`          |
| `--enable-libx264`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libx265`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libxavs2`          | Sí    | Sí            | Sí      | No                              | Test encoder `libxavs2`          |
| `--enable-libxvid`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libzimg`           | Sí    | Sí            | Sí      | Sí                              | -                                |
| `--enable-libzvbi`           | Sí    | Sí            | Sí      | No                              | Requiere VBI stream              |
| `--enable-mediacodec`        | No    | No            | Sí      | Sí                              | (Solo Android)                   |
| `--enable-jni`               | No    | No            | Sí      | No (Implícito para Android)     | -                                |

## Análisis

La gran mayoría de los flags de compilación habilitan dependencias externas o algoritmos. Muchos de estos son librerías de codificación (encoders) o filtros, de los cuales `test_ffmpeg.py` ya prueba los más populares (x264, x265, aom, etc.). Sin embargo, faltan pruebas explícitas para algunos de los encoders/filtros compilados, tales como:

- `libkvazaar` (Encoder HEVC alternativo)
- `libxavs2` (Encoder AVS2)
- `liboapv` (Encoder OAPV)
- `libvvenc` (Encoder VVC/H.266)
- `libopencore-amrwb` (Encoder AMR-WB)
- `libvpl` (Intel QSV Hardware Acceleration)
- `chromaprint` (Filtro de audio)
- `librubberband` (Filtro de audio)
- `libplacebo` (Filtro de video)
- `libvmaf` (Filtro de evaluación de video)
- `libxml2` (Muxer DASH)

Para los decoders (dav1d, davs2, aribb24, zvbi, openmpt, gme), es complejo crear pruebas puras con `lavfi` (generador de test de ffmpeg) porque requieren un archivo de entrada de ese formato para decodificarse.
Para los protocolos (srt, rist, ssh, zmq), requieren servidores de destino o sockets para probar la conexión, por lo que una prueba aislada sin servidor arrojaría error de conexión, aunque confirmaría que FFmpeg intenta usar el protocolo.

## Acción a tomar

Agregaremos las pruebas faltantes en `test_ffmpeg.py` para los encoders y filtros que podemos probar localmente (usando `lavfi` u otras técnicas) como `libkvazaar`, `libvpl`, `libxavs2`, `liboapv`, `libvvenc`, `libopencore-amrwb`, `chromaprint`, `librubberband`, `libplacebo`, `libvmaf`, `dash` y validaremos la existencia de protocolos como `tls`.
