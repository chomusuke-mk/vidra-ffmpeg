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
patch --forward --batch -p0 < "$PATCHES_DIR/android-arm64-v8a-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-armeabi-v7a-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-x86-meson.patch" || true
patch --forward --batch -p0 < "$PATCHES_DIR/android-x86_64-meson.patch" || true

echo "Agregando msvcrt"
patch --forward --batch -p0 < "$PATCHES_DIR/windows-msvcrt_compat.patch" || true

echo "Agregando pkg-config"
patch --forward --batch -p0 < "$PATCHES_DIR/windows-pkg-config.patch" || true
	popd
	
	echo "Descargando dependencias de libjxl"
	if [ -d "$SRC_ROOT/libjxl" ]; then
		pushd "$SRC_ROOT/libjxl"
		./deps.sh
		popd
	fi
	
	echo "Descargando dependencias de shaderc"
	if [ -d "$SRC_ROOT/shaderc" ]; then
		pushd "$SRC_ROOT/shaderc"
		./utils/git-sync-deps
		popd
	fi
	
	if [ -d "$SRC_ROOT/uavs3d" ]; then
		echo "Generando version.h para uavs3d"
		cat <<EOF > "$SRC_ROOT/uavs3d/version.h"
#ifndef __VERSION_H__
#define __VERSION_H__
#define VER_MAJOR  1
#define VER_MINOR  0
#define VER_BUILD  0
#define VERSION_TYPE "release"
#define VERSION_STR  "1.0.0"
#define VERSION_SHA1 "unknown"
#endif // __VERSION_H__
EOF
	fi

	if [ -d "$SRC_ROOT/libpulse" ]; then
		echo "Generando .tarball-version para libpulse"
		echo "17.0" > "$SRC_ROOT/libpulse/.tarball-version"
	fi
	
	echo "================ Parches aplicados ==================="
