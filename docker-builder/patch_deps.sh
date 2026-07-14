#!/bin/bash
set -euo pipefail

PATCHES_DIR="/docker-builder/patches"
SRC_ROOT="/build-env/sources"

echo "================ Aplicando parches ==================="

echo "Parcheando libva"
(cd "$SRC_ROOT/libva" && patch -p4 < "$PATCHES_DIR/libva_meson.patch")

echo "Parcheando Vulkan-Loader"
(cd "$SRC_ROOT/vulkan-loader" && patch -p4 < "$PATCHES_DIR/vulkan_loader.patch")

echo "Parcheando libxml2"
(cd "$SRC_ROOT/libxml2" && patch -p1 < "$PATCHES_DIR/libxml2_android_socklen.patch" || true)

echo "================ Parches aplicados ==================="
