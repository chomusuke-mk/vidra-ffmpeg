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

#echo "Descargando dependencias de libjxl"
#if [ -d "$SRC_ROOT/libjxl" ]; then
#	pushd "$SRC_ROOT/libjxl" >/dev/null
#	./deps.sh
#	popd >/dev/null
#fi

echo "Configurando fast_float para libplacebo"
if [ -d "$SRC_ROOT/libplacebo" ] && [ -d "$SRC_ROOT/fast_float" ]; then
	mkdir -p "$SRC_ROOT/libplacebo/3rdparty"
	mv "$SRC_ROOT/fast_float" "$SRC_ROOT/libplacebo/3rdparty/"
fi

echo "================ Parches aplicados ==================="
