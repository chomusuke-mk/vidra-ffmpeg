# Plan para ampliar FFmpeg optimizado para yt-dlp

Objetivo: incorporar librerías adicionales (CPU/GPU), alinear `config.sh` con `libraries.md`, ajustar scripts de build (Windows/Android), definir flags de compilación y supresiones de warnings, y asegurar integración correcta de DLL en `ffmpeg.exe`. Cada etapa incluye propósito, acciones y criterios de verificación.

1. Auditoría de `libraries.md` y brecha con `config.sh`

- Propósito: garantizar que la tabla refleje el set real de librerías y cubrir casos de yt-dlp (contenedores, códecs, red, subtítulos, filtros) y aceleración por OS/arquitectura.
- Acciones: comparar `LIBS_COMMON`, `LIBS_LINUX`, `LIBS_WINDOWS`, `LIBS_ANDROID` vs tabla. Identificar faltantes clave: `libvmaf`, `libplacebo` (Linux), `librist`, `libzmq`, `chromaprint`, `frei0r`, `libsndfile`/`speex`/`gsm`/`gme` (decodificadores varios), `libzvbi` (teletexto/cc), `libbluray`/`libdvd*` (si se desean discos), `libx265`/`libsvtav1`/`librav1e`/`libxvid`/`libtheora` (códecs CPU), `fdk-aac` (si se acepta licencia nonfree), `libaribb24`/`libaribcaption` (subtítulos arib), `libssh` (SFTP), `libsnappy` (containers), `sdl2` (ffplay opcional), `openh264` (si se necesita h264 libre de patentes locales).
- Verificación: checklist de coincidencia tabla↔config; decidir por OS si se incluyen (Linux: GPU/CPU extra; Windows: evitar deps dinámicas pesadas; Android: solo libs que el NDK soporta o tengamos recetas).

2. Actualizar `libraries.md`

- Propósito: documentar claramente qué se habilitará por target y por aceleración (CPU/GPU) y qué es opcional/licenciado.
- Acciones: añadir filas para libs faltantes priorizadas; marcar disponibilidad por OS (ej. `libplacebo` solo Linux, `schannel` solo Windows, `mediacodec`/`jni` Android, `vaapi`/`vdpau` Linux, `nvcodec` Linux, `dxva2`/`d3d11va` Windows). Anotar licenciamiento especial (GPL, nonfree) y motivación yt-dlp.
- Verificación: tabla consistente con `config.sh` y notas de licencia/OS.

3. Completar `config.sh`

- Propósito: que las listas `LIBS_*` incluyan los paquetes priorizados y segmentados por OS/ABI.
- Acciones:
  - `LIBS_COMMON`: añadir códecs/filtros faltantes que sean multiplataforma (p.ej. `libvmaf`, `libzvbi`, `chromaprint`, `librist`, `libzmq`, `libsnappy`, `libx265`, `libsvtav1`, `librav1e`, `libxvid`, `libtheora`, `libaribcaption`/`libaribb24`, `libssh`, `libbluray` si se desea; considerar `fdk-aac` si aceptable).
  - `LIBS_LINUX`: mantener GPU (`vaapi`, `vulkan`, `libshaderc`, `opencl`, `libvpl`, `nvcodec`) y agregar `libplacebo`, `vdpau` (si se soporta), `openh264` opcional.
  - `LIBS_WINDOWS`: evaluar `librist`, `libzmq`, `chromaprint`, `libzvbi`, `libopenmpt` solo si static-friendly en MSYS2; mantener `schannel`, `dxva2`, `d3d11va`; documentar exclusiones (p.ej. omitir `libplacebo` por DLLs shaderc compartidas).
  - `LIBS_ANDROID`: mantener `mediacodec`, `jni` y solo libs con recetas disponibles; evitar libs sin toolchain probado (ej. `nvcodec`).
- Verificación: `collect_target_libs windows|linux|android` produce sets coherentes; sin duplicados tras ordenar.

4. Integración de DLL en `ffmpeg.exe` (Windows)

- Propósito: definir si se distribuye 100% estático o con DLLs empaquetadas.
- Acciones:
  - Revisar qué libs de MSYS2 solo existen como `.dll.a` (p.ej. `libshaderc_shared`) y decidir si se excluyen o se copia la DLL al `dist/windows` junto a `ffmpeg.exe` con `COPYING` si aplica.
  - Mantener wrapper de `pkg-config` que elimina `-lgcc_s`; extenderlo si nuevas libs introducen DLL obligatorias y evaluar `--extra-ldflags` para forzar estáticos.
  - Validar `ldd`/`objdump -p ffmpeg.exe` para asegurar solo dependencias permitidas (ucrtbase/winpthreads aceptables).
- Verificación: `ffmpeg.exe` corre en VM limpia; no reclama DLL faltantes; `ffmpeg -version` muestra los features añadidos.

5. Ajustes en scripts (`common_libs.sh`, `main.sh`, `platforms/windows.sh`, `platforms/android.sh`)

- Propósito: soportar nuevas libs y mantener builds reproducibles.
- Acciones:
  - Ampliar `ffmpeg_feature_flags` para libs que falten (ej. `libplacebo` ya contemplado, pero añadir casos para `vdpau`, `fdk-aac`, `libopenmpt`, `libsndfile`, etc.) con detección via `pkg-config` y mensajes claros.
  - Inyectar nuevas rutas de `pkg-config`/`LDFLAGS` donde se agreguen bundles en `COMMON_SRC_BUNDLES` (ej. `libvmaf`, `chromaprint`).
  - En `windows.sh`: revisar `--extra-cflags`/`--extra-ldflags` para las nuevas libs; generar alias `.a` si solo hay `.dll.a`; decidir si habilitar ASM (`--enable-x86asm`) si las dependencias lo permiten; mantener supresiones `MINGW_SUPPRESS_WARNINGS` y ampliarlas si FFmpeg 8.x emite warnings nuevos.
  - En `android.sh`: añadir recetas solo para libs viables en NDK (p.ej. `librist`/`libzmq` complejas; priorizar `libvmaf` C-only if cross builds succeed); asegurar `ANDROID_STL=c++_static` consistente; mantener ruta de fribidi en `/tmp` para evitar clock-skew; propagar flags de warnings si se añaden.
- Verificación: `ffmpeg_feature_flags` devuelve flags para cada lib; build scripts no fallan en pkg-config; builds completan en CI local.

6. Flags de compilación y estándares

- Propósito: alinearse con estándares soportados por FFmpeg (C11 recomendado) y toolchains por OS; endurecer sin romper warnings.
- Acciones:
  - Migrar `--extra-cflags` a `-std=gnu11` (FFmpeg 8.x acepta) salvo que algún target requiera `gnu99`; documentar fallback.
  - Añadir hardening ligero donde aplique (`-fstack-protector-strong`, `-D_FORTIFY_SOURCE=2`) para Linux/Android si no rompe linking; evaluar en Windows mingw.
  - Mantener `-pthread` y `-DPTW32_STATIC_LIB` donde corresponda.
- Verificación: `configure` no se queja de estándar; builds sin nuevos warnings fatales.

7. Supresión controlada de warnings

- Propósito: limpiar ruido sin ocultar errores reales.
- Acciones:
  - Catalogar warnings actuales de FFmpeg 8.x en los targets; añadir a `MINGW_SUPPRESS_WARNINGS` y equivalentes por target: `-Wno-deprecated-declarations`, `-Wno-array-parameter`, `-Wno-unused-but-set-variable`, `-Wno-unknown-pragmas`, `-Wno-maybe-uninitialized` según aparezcan.
  - Aplicar flags solo en `--extra-cflags` de FFmpeg (no en deps) para no silenciar problemas aguas arriba.
- Verificación: logs de build limpios; sin supresiones globales que tapen errores nuevos.

8. Validación final

- Propósito: confirmar funcionalidad y dependencias mínimas.
- Acciones:
  - Ejecutar builds de prueba por target (`linux`, `windows`, `android` ABI representativa).
  - Revisar `ffmpeg -buildconf` y `-codecs`/`-filters` para ver features nuevos.
  - En Windows: `objdump -p ffmpeg.exe | findstr DLL` para dependencia residual; en Linux/Android: `readelf -d` para `NEEDED`.
  - Pruebas rápidas con yt-dlp (extract + transcode) y filtros clave (libass, zimg, vmaf si aplica).
- Verificación: binaries funcionales, sin dependencias ausentes, features reflejados en `libraries.md`.
