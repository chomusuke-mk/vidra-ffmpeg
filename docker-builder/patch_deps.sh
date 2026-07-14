#!/bin/bash
set -euo pipefail

PATCHES_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

echo "================ Aplicando parches ==================="
pushd "$SRC_ROOT"

echo "Parcheando mingw-toolchain"
patch --forward --batch -p0 < "$PATCHES_DIR/mingw-toolchain.patch" || true

echo "Parcheando mingw-meson"
patch --forward --batch -p0 < "$PATCHES_DIR/mingw-meson.patch" || true

popd
echo "================ Parches aplicados ==================="
