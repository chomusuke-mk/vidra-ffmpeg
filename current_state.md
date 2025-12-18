# Estado actual del proyecto (vidra-ffmpeg)

Fecha: 17 de diciembre de 2025

Este documento describe el estado **actual** del repositorio `vidra-ffmpeg`: estructura, funcionamiento, decisiones técnicas vigentes (especialmente para **Linux estático**), estado de integración de librerías, problemas conocidos y el **plan de cambio actual** con sus etapas.

> Nota: el objetivo del repo es producir artefactos `ffmpeg` (y en Windows `ffmpeg.exe`) por plataforma, idealmente como **un solo binario** por target/variant, enlazando lo más posible de forma estática. El “full” incluye más features (ej. NVENC/nvcodec, etc.).

---

## 1) Estructura del repositorio

Raíz:

- `docker-compose.yml`

  - Define el servicio `ffmpeg-builder`.
  - Monta volúmenes:
    - `./output` → `/output` (artefactos finales)
    - `./sources` → `/build/sources` (cache de fuentes; persiste entre ejecuciones)
    - `./config.sh` → `/build/config.sh:ro` (config de librerías y variantes)
    - `./scripts` → `/build/scripts:ro` (scripts de orquestación)

- `Dockerfile`

  - Base: `ubuntu:24.04`
  - Instala toolchain y dependencias (compiladores, cmake/ninja, pkg-config, yasm/nasm, etc.)
  - Instala **paquetes -dev** para muchas librerías (fontconfig, freetype, fribidi, harfbuzz, libass, dav1d, lame, openjpeg, snappy, soxr, ssh, svt-av1, vpl, vpx, webp, x265, xml2, opus, vulkan, zimg, openssl, opencl, etc.)
  - Instala **CUDA toolkit 12.6** (Ubuntu 24.04) para habilitar NVENC/CUDA (principalmente headers + toolchain CUDA; el runtime real de NVENC depende de driver host).
  - Descarga Android NDK (r27b) para builds Android.

- `config.sh`

  - Define la **matriz de librerías** solicitadas por plataforma, y el tipo de build (standard/full).
  - Variables principales:
    - `FFMPEG_VERSION` (ej. 8.0.1)
    - `EXTRA_VERSION`
    - `LIBS_COMMON`, `LIBS_LINUX`, `LIBS_WINDOWS`, `LIBS_ANDROID`
    - `LIBS_*_EXTENDED` (para variant `full`)
    - `FFMPEG_BUILDS` (ej. `full`)

- `scripts/`

  - `main.sh`: entrypoint lógico (invocado por docker-compose) que despacha al script de plataforma.
  - `common_libs.sh`: corazón del sistema (resuelve config, descarga fuentes, construye algunas libs desde fuente, arma flags de FFmpeg según `pkg-config` y la política de build).
  - `platforms/`
    - `linux.sh`: orquestación build Linux
    - `windows.sh`: orquestación build Windows (mingw)
    - `android.sh`: orquestación build Android (NDK)
  - `deps/windows/`: helpers para preparar sysroot MSYS2 para Windows.

- `sources/`

  - Cache de repos/fuentes descargadas y (en algunos casos) fuentes “vendor” para construir libs desde código fuente.
  - Importante: este directorio se monta como volumen y **persiste**.

- `output/`

  - Salida final por versión/variant/OS:
    - Ejemplo Linux full: `/output/8.0.1-full/linux/ffmpeg`
    - Windows: `/output/<ver>/windows/ffmpeg.exe`

- `examples/` y `prev_version/`
  - Contienen scripts y/o referencias históricas (ej. `FFmpeg-Builds-master`) y planes anteriores.

---

## 2) Objetivo funcional (qué hace el proyecto)

- Construye FFmpeg desde fuente (`ffmpeg.org/releases/...`) y lo empaqueta para múltiples plataformas.
- Selecciona features (encoders/decoders/libs externas) a partir de una lista declarativa en `config.sh`.
- Para cada plataforma (Linux/Windows/Android) y para cada “variant” (standard/full), produce un binario `ffmpeg` final en `output/`.

### Variants: `standard` vs `full`

- `standard`: usa `LIBS_COMMON` + libs específicas del target.
- `full`: agrega `LIBS_*_EXTENDED` (por target) además de las comunes.

En este repo, actualmente `FFMPEG_BUILDS="full"`.

---

## 3) Flujo de compilación (macro)

### 3.1 Docker como entorno reproducible

- El build se ejecuta dentro del contenedor `ffmpeg-builder`.
- La fuente de FFmpeg y librerías se mantiene en `sources/` (montado como `/build/sources`).
- Los binarios finales se exportan en `output/`.

Comandos típicos:

- Construir Linux:
  - `docker compose run --rm ffmpeg-builder linux`
- Construir Windows:
  - `docker compose run --rm ffmpeg-builder windows`
- Construir Android:
  - `docker compose run --rm ffmpeg-builder android`

Logs:

- Comúnmente se redirige stdout/stderr:
  - `docker compose run --rm ffmpeg-builder linux > logs/linux.log 2>&1`

### 3.2 `scripts/main.sh`

- Actúa como dispatcher:
  - Según argumento (`linux`, `windows`, `android`) llama al script en `scripts/platforms/`.

### 3.3 `scripts/common_libs.sh` (núcleo)

Responsabilidades principales:

1. Cargar configuración (`load_config`) desde `/build/config.sh`.
2. Asegurar fuentes (`ensure_sources`):
   - Clona x264 desde Git.
   - Descarga tarball de FFmpeg.
   - Prefetch de “bundles” comunes (zlib, brotli, openssl, expat, libxml2) si se solicitan.
3. Proveer builders de algunas libs cuando no vienen bien desde distro:
   - `build_x264` (siempre se compila x264 desde fuente).
   - `build_svtav1` (se compila SVT-AV1 desde GitLab cuando se pide).
   - `build_vulkan` (headers+loader más nuevo cuando se necesita y no está disponible en system).
   - `prepare_nvcodec_headers` (instala nv-codec-headers en el prefix correcto).
4. Resolver “qué flags pasar a FFmpeg” (`ffmpeg_feature_flags`):
   - Hace detección por `pkg-config`.
   - En builds estáticos, aplica una política más estricta para evitar habilitar libs que romperían el link.
   - Emite logs `[WARN]` cuando una lib solicitada no puede habilitarse.

---

## 4) Estado específico por plataforma

### 4.1 Linux

#### 4.1.1 Script: `scripts/platforms/linux.sh`

- Establece `PREFIX=/build/dist/linux`.
- Define `PKG_CONFIG_PATH` con:

  - `$PREFIX/lib/pkgconfig`
  - `$PREFIX/lib64/pkgconfig`

- Tiene un “modo” importante:
  - `FFMPEG_LINUX_STATIC` (default actual: **1**)

Esto implica:

- Build “fully static”:

  - `CFLAGS="-O3 -static"`
  - `LDFLAGS="-static"`
  - FFmpeg `./configure` usa:
    - `--enable-static --disable-shared`
    - `--pkg-config-flags=--static`
    - `--extra-ldflags=-static`

- Validación post-build:
  - Usa `file` y busca `statically linked`.
  - Si se está en modo estático, imprime `ÉXITO: El binario es estático.` si coincide.

#### 4.1.2 Estado del binario Linux

- Se está produciendo un `ffmpeg` exportado como:

  - `/output/<ver>-full/linux/ffmpeg`

- En iteraciones previas se verificó con:
  - `file` → “statically linked”
  - `ldd` → “not a dynamic executable”

#### 4.1.3 NVENC / nvcodec en Linux

- `config.sh` incluye `nvcodec` dentro de `LIBS_LINUX_EXTENDED`.
- `common_libs.sh` habilita para Linux:
  - `--enable-ffnvcodec --enable-nvenc`
  - e instala headers con `prepare_nvcodec_headers "/usr/local"`.

Observación importante:

- NVENC no “inyecta” una dependencia `libnvidia-encode.so` dentro del binario (es un API hacia el driver); la funcionalidad real depende del runtime/driver del host.
- Aun así, el objetivo del repo es que **el binario `ffmpeg` sea uno**.

#### 4.1.4 Estado del linking estático de “librerías adicionales” en Linux

El estado actual es **mixto**:

- x264: se compila desde fuente y se integra correctamente.
- SVT-AV1: se compila desde fuente cuando se solicita y se instala en `$PREFIX` con `.a` + `.pc`.
- Para muchas libs “de distro” (apt `lib*-dev`):
  - Es posible que existan `.a`, pero los tests de `configure` de FFmpeg pueden fallar en modo `-static` si:
    - el `.pc` no expone bien deps privadas
    - o el test linkea con `-l<lib>` pero sin `-lcrypto/-lssl/-lz/...` y rompe

En la iteración actual se cambió el comportamiento para que si una lib solicitada no se puede habilitar en modo estático, se reporte como:

- `[WARN] <lib> detectado pero no linkeable estáticamente; omitiendo`

Esto cumple con tu criterio: “si faltan librerías debe ser WARN, no INFO”.

**Situación detectada (reciente):**

- En una recompilación donde se habilitaron más flags (porque la detección estática se volvió menos estricta), `./configure` falló en `libssh` al intentar linkear un test con `-lssh` pero sin `-lcrypto/-lssl`.
- Se intentó corregir añadiendo `--extra-libs="-lssl -lcrypto -lz -ldl -lm -lpthread -lstdc++ -latomic"` en Linux para que esos tests pasen.
- En el momento de escribir este documento, la build Linux estaba en una nueva iteración (requiere revisar el final de `logs/linux.log` para el error exacto post-cambio).

---

### 4.2 Windows

#### 4.2.1 Script: `scripts/platforms/windows.sh`

- Usa `mingw-w64` con cross prefix `x86_64-w64-mingw32-`.
- Prepara un sysroot desde MSYS2 mediante `scripts/deps/windows/fetch_msys2.sh`.
- Política declarada:
  - “se intenta binario 100% estático; si alguna lib solo existe como DLL, debe ir junto a ffmpeg.exe...”

Técnicas destacadas:

- `--enable-static --disable-shared` + flags `-static`, `-static-libgcc`, `-static-libstdc++`.
- Wrapper de `pkg-config` para filtrar referencias a `-lgcc_s`.
- Crea un `libcompatstat64.a` para proveer símbolos CRT legacy que algunas libs referencian.

**Resultado:**

- Windows tiende a quedar “todo en un exe” con workarounds específicos.

---

### 4.3 Android

- El NDK está instalado en el contenedor (`/opt/android-ndk`).
- `scripts/platforms/android.sh` (no detallado aquí por no haberse inspeccionado en esta sesión) suele:
  - configurar toolchain de Android
  - compilar para ABIs configuradas
  - exportar a `/output`.

**Objetivo:** binarios por ABI, con librerías estáticas integradas.

---

## 5) Configuración actual (qué libs se piden hoy)

De `config.sh`:

- `LIBS_COMMON`:

  - `x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi libass libmp3lame opus libdav1d libvpx libwebp libopenjpeg zimg libsoxr`

- `LIBS_LINUX`:

  - `fontconfig libx265 libsvtav1 libsnappy libssh`

- `LIBS_LINUX_EXTENDED` (full):

  - `libvpl vaapi vulkan opencl nvcodec`

- `FFMPEG_BUILDS="full"`

Interpretación:

- El build Linux full pretende habilitar un set grande.
- En modo **fully static** (`-static`), esto exige que cada dependencia sea realmente linkeable en estático (y que `configure` encuentre todo de forma consistente).

---

## 6) Políticas actuales de logging (WARN/INFO)

Actualmente:

- Cuando una lib solicitada no se puede usar (missing o no linkeable estáticamente) se emite `[WARN]`.
- Antes existía un caso donde se degradaba a `[INFO]` cuando “no linkeable estáticamente”, pero eso se cambió para cumplir la importancia de esas libs.

En particular:

- `add_flag_if_pkg` ahora emite `[WARN] ... detectado pero no linkeable estáticamente; omitiendo`.
- `nvcodec` también se reporta como `[WARN]` si se omite por configuración.

---

## 7) Estado del plan de cambio actual (etapas)

### Etapa 0 — Base estable (completada)

Objetivo:

- Build Linux produce un binario `ffmpeg` “statically linked” y exporta a `/output/.../linux/ffmpeg`.

Hechos:

- `FFMPEG_LINUX_STATIC` por defecto está en `1`.
- `--pkg-config-flags=--static` está corregido (sin comillas erróneas).
- El chequeo post-build de `ldd` ya no se usa como verificación principal (porque `ldd` falla en estáticos); se usa `file`.

### Etapa 1 — “WARN estrictos” (completada)

Objetivo:

- Si una lib pedida no entra, debe quedar en `[WARN]` (no “INFO”).

Hechos:

- Ajustado en `scripts/common_libs.sh`.

### Etapa 2 — Mejorar detección real de estático (en progreso)

Problema raíz:

- `pkg_static_ok` se usa para decidir si una lib puede habilitarse en build `-static`.
- Se detectaron falsos negativos por:
  - `.pc` que no declara `libdir` ni produce `-L` (ej. zlib)
  - tokens vacíos por `tr ' ' '\n'` (generaba check de `lib.a` inexistente)

Cambios implementados:

- `pkg_static_ok` ahora:
  - ignora líneas vacías
  - agrega rutas estándar `/usr/lib/x86_64-linux-gnu`, etc. cuando no hay `-L`

Estado:

- La detección mejoró, pero esto puede “destapar” el siguiente problema real: **tests de FFmpeg configure** que linkean insuficientemente.

### Etapa 3 — Pasar configure tests en modo fully static (en progreso)

Problema raíz:

- Algunos checks de `./configure` prueban con `-l<lib>` sin arrastrar todas las deps que se necesitan en estático.
  - Ejemplo típico: `libssh` requiere símbolos de OpenSSL (`libcrypto`, `libssl`).

Cambio intentado:

- Añadir `--extra-libs` en Linux con un set mínimo (ssl/crypto/z/pthread/dl/m/stdc++/atomic).

Estado:

- La build falló nuevamente (exit 1) y requiere inspección del final del `logs/linux.log` para el error exacto de esta iteración.

### Etapa 4 — Asegurar “librerías adicionales” estáticas como en Windows/Android (pendiente)

Meta explícita (tu requerimiento):

- En Linux, igual que en Android/Windows, enlazar estáticamente las librerías adicionales y terminar con **un solo `ffmpeg`**.

Estrategia recomendada (la más robusta):

1. Construir desde fuente e instalar en `$PREFIX` (como ya se hace con x264 y svt-av1) las libs que son problemáticas en estático:

   - `freetype`, `harfbuzz`, `fribidi`, `fontconfig`, `libass`
   - `libssh` (idealmente contra openssl también buildado en PREFIX)
   - `dav1d`, `soxr`, `snappy`, `x265`, `vpx`, `webp`, `xml2`, `zimg`, `opus`, `zlib`, `openssl`, etc.

2. Asegurar `.pc` correctos:

   - `Libs:` debe incluir deps necesarias para que FFmpeg configure no falle.
   - en estático, muchas deps están en `Libs.private`, pero FFmpeg configure puede no usarlas como esperas.

3. Mantener `PKG_CONFIG_PATH` priorizando `$PREFIX`:
   - Para que `pkg-config` use tus builds estáticos y no los de distro.

Resultado esperado:

- `ffmpeg -buildconf` debe mostrar `--enable-libass`, `--enable-libfreetype`, `--enable-libharfbuzz`, `--enable-libxml2`, etc.
- `file` debe seguir mostrando `statically linked`.

### Etapa 5 — Vulkan/VAAPI/OpenCL en fully static (pendiente / probablemente limitado)

- Vulkan: el loader suele ser `.so` y no encaja bien con `-static` “puro”.
- VAAPI/OpenCL: en distros suele ser difícil lograr 100% estático.

Política probable:

- Mantener `[WARN]` y omitir en modo fully-static si no hay una ruta viable.

---

## 8) Problemas conocidos y limitaciones

1. **Static linking real** en Linux es “estricto”:

   - si una lib no tiene `.a` o tiene deps que no están disponibles en `.a`, no se podrá integrar.

2. **FFmpeg configure** puede fallar aunque `pkg-config` encuentre el paquete:

   - por tests de enlace mínimos (`-lfoo`) que no incluyen deps.

3. **Diferencias entre “static de FFmpeg” y “fully static del binario”**:

   - `--enable-static --disable-shared` no garantiza un binario 100% estático si no se usa `-static`.
   - En este repo, Linux “fully static” se fuerza con `-static`.

4. Docker Desktop en Windows + bind mounts:
   - Borrados grandes `rm -rf` pueden fallar con “Directory not empty”.
   - Mitigación implementada para SVT-AV1: build en `/tmp/svt-av1-build`.

---

## 9) Cómo validar el resultado

Para Linux:

1. Verificar que el binario exportado existe:

   - `/output/<ver>-full/linux/ffmpeg`

2. Verificar estático:

   - `file /output/<ver>-full/linux/ffmpeg`
   - opcional: `ldd /output/<ver>-full/linux/ffmpeg` (debería decir “not a dynamic executable”).

3. Verificar features:

   - `/output/<ver>-full/linux/ffmpeg -buildconf`
   - Buscar `--enable-libass`, `--enable-libx265`, etc.
   - Buscar `--enable-ffnvcodec --enable-nvenc`.

4. Ver warnings en el build:
   - revisar `logs/linux.log` y buscar `\[WARN\]`.

---

## 10) Próximos pasos inmediatos (acción recomendada)

Para cumplir completamente “Linux igual que Android/Windows (todo en 1 binario con libs extra estáticas)”, el siguiente paso práctico es:

1. Hacer la build Linux pasar de “best effort + warnings” a “buildar desde fuente al PREFIX en Linux” para las libs críticas, en orden:

   - `zlib`, `openssl`
   - `libssh` (contra openssl del PREFIX)
   - `freetype`, `harfbuzz`, `fribidi`, `fontconfig`, `libass`
   - `dav1d`, `opus`, `soxr`, `snappy`, `openjpeg`, `xml2`, etc.

2. Ajustar `.pc` de esas libs para estático (cuando sea necesario), replicando la técnica usada en `SvtAv1Enc.pc`.

3. Mantener `[WARN]` solo para:
   - features no viables en fully static (probable: vulkan-loader, vaapi, algunos opencl stacks), o
   - libs que todavía no tengan builder.

---

## 11) Estado de cambios de código (resumen)

Cambios relevantes en esta sesión (a alto nivel):

- `scripts/common_libs.sh`:

  - Se endureció el logging a `[WARN]` cuando una lib solicitada no entra en build estático.
  - Se corrigieron falsos negativos en detección estática (`pkg_static_ok`) por:
    - `.pc` sin libdir / sin -L
    - tokens vacíos que provocaban chequeo de `lib.a`

- `scripts/platforms/linux.sh`:
  - Se añadió un `--extra-libs` en modo fully static (para ayudar a tests de configure con deps estáticas).

> Nota: la etapa actual es iterativa: a medida que se habiliten más libs, aparecerán fallos de `configure`/link y habrá que resolverlos construyendo esas libs en `$PREFIX` o ajustando flags/deps.

---

## 12) Referencias internas rápidas

Archivos clave:

- `config.sh` (lista de libs y variantes)
- `docker-compose.yml` (orquestación)
- `Dockerfile` (deps y toolchains)
- `scripts/common_libs.sh` (detección + flags + builds desde fuente)
- `scripts/platforms/linux.sh` (modo estático Linux y export)
- `scripts/platforms/windows.sh` (estrategia estática mingw)

Artefactos:

- `output/<ver>-full/linux/ffmpeg`
- `logs/linux.log`
