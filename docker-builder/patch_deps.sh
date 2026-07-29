#!/bin/bash
set -euo pipefail

PATCHES_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

echo "================ Aplicando parches ==================="
pushd "$SRC_ROOT" >/dev/null

echo "Aplicando todos los parches generados..."
for patch_file in "$PATCHES_DIR"/*.patch; do
	echo "Aplicando $(basename "$patch_file")"
	patch --batch --binary -p0 <"$patch_file"
done

popd >/dev/null

echo "Configurando dependencias de libjxl"
pushd "$SRC_ROOT/libjxl" >/dev/null
rmdir "testdata" "third_party/brotli" "third_party/googletest" "third_party/highway" "third_party/sjpeg" "third_party/skcms" "third_party/zlib" "third_party/libpng" "third_party/libjpeg-turbo"
mv "$SRC_ROOT/libjxl-testdata" "testdata"
mv "$SRC_ROOT/libjxl-brotli" "third_party/brotli"
mv "$SRC_ROOT/libjxl-googletest" "third_party/googletest"
mv "$SRC_ROOT/libjxl-highway" "third_party/highway"
mv "$SRC_ROOT/libjxl-sjpeg" "third_party/sjpeg"
mv "$SRC_ROOT/libjxl-skcms" "third_party/skcms"
mv "$SRC_ROOT/libjxl-zlib" "third_party/zlib"
mv "$SRC_ROOT/libjxl-libpng" "third_party/libpng"
mv "$SRC_ROOT/libjxl-libjpeg-turbo" "third_party/libjpeg-turbo"
popd >/dev/null

echo "Configurando fast_float para libplacebo"
mkdir -p "$SRC_ROOT/libplacebo/3rdparty"
mv "$SRC_ROOT/fast_float" "$SRC_ROOT/libplacebo/3rdparty/"

echo "================ Parches aplicados ==================="
