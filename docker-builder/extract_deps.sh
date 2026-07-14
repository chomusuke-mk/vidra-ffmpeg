#!/bin/bash
set -euo pipefail

#SRC_ROOT="/build-env/sources"
#DOWNLOADS_DIR="/downloads"

SRC_ROOT="../temp/sources"
DOWNLOADS_DIR="../temp/docker-build/downloads"
mkdir -p "$SRC_ROOT"

echo "================ Extrayendo dependencias ==================="

extract() {
	local tarball=$1
	echo "Extrayendo $tarball"
	shopt -s extglob
	name="${tarball#mingw-w64-x86_64-}"
	name="${name%.@(tar.gz|tgz|tar.xz|txz|tar.bz2|pkg.tar.zst)}"
	if [[ "$tarball" == "mingw-w64-x86_64-"* ]]; then
		output="$SRC_ROOT/mingw/$name"
	else
		output="$SRC_ROOT/$name"
	fi
	case "$tarball" in
	*.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.pkg.tar.zst)
		mkdir -p "$output"
		if [[ "$tarball" == "mingw-w64-x86_64-"* ]]; then
			tar -xf "$DOWNLOADS_DIR/$tarball" -C "$output" --strip-components=1
		else
			tar -xf "$DOWNLOADS_DIR/$tarball" -C "$output" --strip-components=1
		fi
		;;
	*)
		echo "Formato de archivo desconocido: $tarball" >&2
		exit 1
		;;
	esac
}

for file in "$DOWNLOADS_DIR"/*.tar.*; do
	name=$(basename "$file")
	extract "$name"
done

# Extract mingw packages to a sysroot?
# Wait, original script used pacman or extracted them.
echo "================ Extracción completada ==================="
