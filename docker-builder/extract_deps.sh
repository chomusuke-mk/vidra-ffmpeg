#!/bin/bash
set -euo pipefail

DOWNLOADS_DIR="$(realpath "$1")"
SRC_ROOT="$(realpath "$2")"

rm -rf "$SRC_ROOT"
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
	*.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.pkg.tar.zst | *.zip)
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
