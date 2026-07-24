#!/bin/bash

mkdir -p ./temp/downloads ./temp/source

./docker-builder/download_deps.sh ./temp/downloads
./docker-builder/extract_deps.sh ./temp/downloads ./temp/source
./docker-builder/patch_deps.sh ./docker-builder/patches ./temp/source

echo "========== ARCHIVOS VISIBLES EN ./temp/source =========="
ls -l ./temp/source
