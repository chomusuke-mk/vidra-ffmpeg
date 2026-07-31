#!/bin/bash
set -euo pipefail

DOWNLOADS_DIR=./temp/downloads
SOURCE_DIR=./temp/source
PATCHED_DIR=./temp/patched
PATCHES_DIR=./docker-builder/patches

for patch in "$PATCHES_DIR"/*.patch; do
	# Require comment in first line
	first_line=$(head -n 1 "$patch")
	if [[ ! "$first_line" =~ ^#\ .*\ -\ .* ]]; then
		echo "Error: El parche $(basename "$patch") no tiene un comentario válido (TARGET:ARCH - ...) en la primera línea."
		#exit 1
	fi
done

mkdir -p $DOWNLOADS_DIR $SOURCE_DIR

./docker-builder/download_deps.sh $DOWNLOADS_DIR
./docker-builder/extract_deps.sh $DOWNLOADS_DIR $SOURCE_DIR
rm -rf $PATCHED_DIR && mkdir -p $PATCHED_DIR
cp -r $SOURCE_DIR/* $PATCHED_DIR
./docker-builder/patch_deps.sh $PATCHES_DIR $PATCHED_DIR

echo "================="
echo "Archivos originales en $SOURCE_DIR"
echo "Archivos parcheados en $PATCHED_DIR"
