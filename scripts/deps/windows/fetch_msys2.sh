#!/bin/bash
set -euo pipefail

# Descarga y extrae paquetes mingw precompilados de MSYS2 hacia el sysroot mingw.
# Requiere: curl, tar, unzstd (paquete zstd).

MSYS2_MIRROR=${MSYS2_MIRROR:-"https://repo.msys2.org/mingw/x86_64"}
SYSROOT_BASE="/usr/x86_64-w64-mingw32"
SYSROOT="$SYSROOT_BASE/mingw64"
MARKER="$SYSROOT/.vidra-msys2.ready"
TMP_DIR=${TMP_DIR:-"/tmp/msys2-pkgs"}

# Lista de paquetes necesarios (alcanza flags actuales en ffmpeg_feature_flags).
PKGS=(
  # Bases requeridas por varios .pc (freetype/fontconfig/harfbuzz)
  mingw-w64-x86_64-bzip2
  mingw-w64-x86_64-brotli
  mingw-w64-x86_64-expat
  mingw-w64-x86_64-graphite2
  mingw-w64-x86_64-libffi
  mingw-w64-x86_64-pcre2
  mingw-w64-x86_64-gettext
  mingw-w64-x86_64-glib2
  mingw-w64-x86_64-libunibreak
  mingw-w64-x86_64-libogg
  mingw-w64-x86_64-fftw
  mingw-w64-x86_64-libsamplerate
  mingw-w64-x86_64-cjson
  mingw-w64-x86_64-mbedtls
  mingw-w64-x86_64-libsodium
  mingw-w64-x86_64-shaderc
  mingw-w64-x86_64-spirv-cross
  mingw-w64-x86_64-spirv-tools
  mingw-w64-x86_64-vulkan-headers
  mingw-w64-x86_64-vulkan-loader
  mingw-w64-x86_64-lcms2
  mingw-w64-x86_64-libdovi

  mingw-w64-x86_64-zlib
  mingw-w64-x86_64-libpng
  mingw-w64-x86_64-freetype
  mingw-w64-x86_64-harfbuzz
  mingw-w64-x86_64-fribidi
  mingw-w64-x86_64-fontconfig
  mingw-w64-x86_64-libass
  mingw-w64-x86_64-libsoxr
  mingw-w64-x86_64-rubberband
  mingw-w64-x86_64-vid.stab
  mingw-w64-x86_64-lame
  mingw-w64-x86_64-opus
  mingw-w64-x86_64-libvorbis
  mingw-w64-x86_64-twolame
  mingw-w64-x86_64-aom
  mingw-w64-x86_64-dav1d
  mingw-w64-x86_64-libvpx
  mingw-w64-x86_64-libwebp
  mingw-w64-x86_64-openjpeg2
  mingw-w64-x86_64-zimg
  mingw-w64-x86_64-vmaf
  mingw-w64-x86_64-libplacebo
  mingw-w64-x86_64-srt
  mingw-w64-x86_64-openssl
  mingw-w64-x86_64-libiconv
  mingw-w64-x86_64-libxml2
)

log(){ echo "[win-deps] $*"; }
fail(){ log "ERROR: $*" >&2; exit 1; }

if ! command -v unzstd >/dev/null 2>&1; then
  fail "unzstd no encontrado; instala el paquete 'zstd' en la imagen base"
fi

mkdir -p "$SYSROOT" "$TMP_DIR"

if [ -f "$MARKER" ]; then
  log "Sysroot ya preparado ($MARKER)";
  exit 0
fi

resolve_pkg_url() {
  local base=$1
  local list
  list=$(curl -fsSL "$MSYS2_MIRROR/") || return 1
  local match
  match=$(printf '%s' "$list" | grep -oE "${base}-[0-9][^\"]*\.pkg\.tar\.zst" | sort | tail -n1)
  if [ -z "$match" ]; then
    return 1
  fi
  printf '%s/%s' "$MSYS2_MIRROR" "$match"
}

for pkg in "${PKGS[@]}"; do
  url=$(resolve_pkg_url "$pkg") || fail "No se pudo resolver URL para $pkg (nombre o mirror incorrecto)"
  fname=$(basename "$url")
  log "Descargando $fname"
  if ! curl -fL "$url" -o "$TMP_DIR/$fname"; then
    fail "No se pudo descargar $url (verifica nombre/mirror)"
  fi
  log "Extrayendo $fname"
  if ! tar --directory="$SYSROOT_BASE" --use-compress-program=unzstd -xf "$TMP_DIR/$fname"; then
    fail "Fallo al extraer $fname"
  fi
done

touch "$MARKER"
log "Dependencias MSYS2 instaladas en $SYSROOT"
