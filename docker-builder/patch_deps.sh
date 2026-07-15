#!/bin/bash
set -euo pipefail

PATCHES_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

echo "================ Aplicando parches ==================="
pushd "$SRC_ROOT"

echo "Parcheando toolchain"
patch --forward --batch -p0 < "$PATCHES_DIR/windows-toolchain.patch" || true

echo "Parcheando meson"
patch --forward --batch -p0 < "$PATCHES_DIR/windows-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-armeabi-v7a-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-x86-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-x86_64-meson.patch" || true

echo "Agregando pkg-config"
patch --forward --batch -p0 < "$PATCHES_DIR/windows-pkg-config.patch" || true
popd
echo "================ Parches aplicados ==================="
