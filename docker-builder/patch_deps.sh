#!/bin/bash
set -euo pipefail

PATCHES_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

echo "================ Aplicando parches ==================="
pushd "$SRC_ROOT"

echo "Parcheando toolchain"
patch --forward --batch -p0 <"$PATCHES_DIR/windows-toolchain.patch" || true

echo "Parcheando meson"
patch --forward --batch -p0 <"$PATCHES_DIR/windows-meson.patch" || true
patch --forward --batch -p0 <"$PATCHES_DIR/android-arm64-v8a-meson.patch" || true
patch --forward --batch -p0 <"$PATCHES_DIR/android-armeabi-v7a-meson.patch" || true
patch --forward --batch -p0 <"$PATCHES_DIR/android-x86-meson.patch" || true
patch --forward --batch -p0 <"$PATCHES_DIR/android-x86_64-meson.patch" || true

echo "Agregando msvcrt"
patch --forward --batch -p0 <"$PATCHES_DIR/windows-msvcrt_compat.patch" || true

echo "Agregando pkg-config"
patch --forward --batch -p0 <"$PATCHES_DIR/windows-pkg-config.patch" || true

echo "Parcheando libuavs3d"
patch --forward --batch -p0 <"$PATCHES_DIR/libuavs3d-version.patch" || true

echo "Parcheando libpulse"
patch --forward --batch -p0 <"$PATCHES_DIR/libpulse-version.patch" || true

popd

echo "Descargando dependencias de libjxl"
if [ -d "$SRC_ROOT/libjxl" ]; then
	pushd "$SRC_ROOT/libjxl"
	./deps.sh
	popd
fi

echo "Descargando dependencias de shaderc"
if [ -d "$SRC_ROOT/libshaderc" ]; then
	echo "Saltando git-sync-deps para shaderc para evitar cuelgues de red..."
	# pushd "$SRC_ROOT/libshaderc"
	# ./utils/git-sync-deps
	# popd
fi

echo "Configurando fast_float para libplacebo"
if [ -d "$SRC_ROOT/libplacebo" ] && [ -d "$SRC_ROOT/fast_float" ]; then
	mkdir -p "$SRC_ROOT/libplacebo/3rdparty"
	mv "$SRC_ROOT/fast_float" "$SRC_ROOT/libplacebo/3rdparty/"
fi

echo "================ Parches aplicados ==================="
