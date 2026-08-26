# Instrucciones y Flujos de Trabajo para el Proyecto Vidra-FFmpeg

Este documento contiene las instrucciones y flujos de trabajo recomendados para trabajar en este repositorio, especialmente para resolver el objetivo de hacer pasar los tests de FFmpeg en Linux sin eliminar _flags_ de compilación.

## Enfoque Holístico

Este proyecto tiene poco código directo pero depende fuertemente de los procesos de descarga, parcheo y compilación de dependencias (en `docker-builder/`). Cualquier error en FFmpeg a menudo se origina en una dependencia mal parcheada o configurada.
**Importante:** No borres los flags de compilación de FFmpeg (`--enable-*`) en `compile.sh`.

## Ciclo de Resolución de Errores

1. **Ejecutar Tests:**
   Usa el script de Python para probar la compilación de Linux:

   ```bash
   python3 test_ffmpeg.py ./dist/linux-x86_64/ffmpeg ./temp/ffmpeg_test
   ```

   Si los tests fallan, revisa el archivo de log `./temp/ffmpeg_test/ffmpeg_test_results.log`.

2. **Identificar la causa raíz:**
   - Puede ser que FFmpeg no compense una dependencia. Revisa los logs de compilación de la librería problemática o de FFmpeg (en el contenedor).
   - Revisa en `docker-builder/*` si se requiere modificar algún script de compilación (como `build_libs.sh`) o modificar/agregar un parche en `docker-builder/patches/`.

3. **Modificar Parches y Validar (Flujo de Parcheo):**
   - Si creas o modificas un `.patch` en `docker-builder/patches/`, valida que aplique correctamente a los archivos fuente.
   - Ejecuta:

     ```bash
     ./view_files.sh
     ```

   - Este script descargará, extraerá y aplicará los parches en `temp/patched`.
   - Revisa los archivos en `temp/patched` para asegurarte de que el código queda tal como esperas justo antes de que `build_libs.sh` lo compile. En `temp/source` quedan los archivos originales.

4. **Reconstruir la Imagen Docker (si se cambiaron scripts o dependencias del sistema):**

   ```bash
   docker compose --progress=plain build
   ```

5. **Recompilar FFmpeg:**
   Ejecuta el builder para Linux:

   ```bash
   docker compose run --rm ffmpeg-builder
   ```

6. **Repetir:**
   Vuelve al paso 1 hasta que pasen todos los tests.

## Archivos Clave

- `compile.sh`: Configuración de FFmpeg y orquestador principal de compilación por plataforma.
- `docker-builder/build_libs.sh`: Construye las dependencias de terceros usando CMake, Meson, Autotools, etc.
- `docker-builder/patch_deps.sh`: Aplica los parches a las dependencias.
- `Dockerfile`: Entorno de compilación con `mega-capa` que descarga, parchea y construye todo.
