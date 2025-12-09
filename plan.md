# Plan para agregar dependencias adicionales (Docker único, multiplataforma)

Objetivo: preparar instalación reproducible de librerías extra para FFmpeg respetando la organización actual (`/build/scripts`, Docker único con targets linux/windows/android).

## Alcance inmediato (paquetes necesarios)

- Windows (mingw, vía binarios MSYS2): aom, dav1d, svt-av1, rav1e, libvpx, libwebp, openjpeg2, zimg, vmaf, libplacebo, freetype, harfbuzz, fribidi, fontconfig, libass, libpng, zlib, libsoxr, librubberband, libvidstab, libmp3lame, opus, vorbis, twolame, srt, rist, ssh, zmq, libbluray, gmp, libxml2.
- Linux/Android: sin cambios hoy; se integrarán luego con bootstraps específicos.

## Pasos

1. **Bootstrap Windows deps**: nuevo script `scripts/deps/windows/fetch_msys2.sh` que descargue/extraiga paquetes `mingw-w64-x86_64-*` requeridos al sysroot `\usr\x86_64-w64-mingw32\sys-root\mingw` con logs claros y marca de finalización.
2. **Integrar en flujo Windows**: actualizar `scripts/platforms/windows.sh` para invocar el bootstrap si el sysroot no está listo, exportar `PKG_CONFIG_LIBDIR` combinando sysroot + prefix, y apuntar `extra-cflags/ldflags` al sysroot para que `./configure` detecte las libs.
3. **Dockerfile**: añadir utilidades mínimas necesarias para extraer `.pkg.tar.zst` (p.ej. `zstd`).
4. **Validaciones y logs**: mensajes `[win-deps]` consistentes; fallo temprano si un paquete no se descarga o si falta `unzstd`.
5. **Extensión futura (no en esta entrega)**: bootstrap Linux/Android desde source y ampliar listas `LIBS_*` en `config.sh`.

## Implementación incremental

- Entrega 1 (ahora): crear `fetch_msys2.sh`, hook en `windows.sh`, y soporte `zstd` en Dockerfile. Mantener builds actuales funcionando; no se activan librerías nuevas salvo que existan las `.pc` en sysroot.
- Entrega 2: completar bootstraps Linux/Android y actualizar `config.sh`.

## Consideraciones

- Uso de marker file en sysroot para evitar re-descargas.
- Descargas desde mirror MSYS2 configurables por variable `MSYS2_MIRROR`.
- Logs de advertencia si faltan binarios de extracción o si un paquete falla.
