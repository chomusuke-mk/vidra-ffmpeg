#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p temp/docker-build/downloads
mkdir -p temp/docker-build/logs
rm -f temp/docker-build/logs/*.log

echo ">>> Descargando dependencias previas al build de Docker <<<"
echo "Los logs se guardaran en temp/docker-build/logs/download_deps.log"

{
    NDK_VERSION="r27d"
    NDK_ZIP="android-ndk-${NDK_VERSION}-linux.zip"
    if [ ! -f "temp/docker-build/downloads/$NDK_ZIP" ]; then
        echo "Descargando Android NDK $NDK_VERSION..."
        curl -L --fail "https://dl.google.com/android/repository/$NDK_ZIP" -o "temp/docker-build/downloads/$NDK_ZIP.tmp"
        mv "temp/docker-build/downloads/$NDK_ZIP.tmp" "temp/docker-build/downloads/$NDK_ZIP"
    else
        echo "NDK $NDK_VERSION ya descargado."
    fi

    if [ -f "docker-builder/download_deps.sh" ]; then
        bash docker-builder/download_deps.sh
    fi
} > temp/docker-build/logs/download_deps.log 2>&1

echo ">>> Construyendo imagen de Docker masiva <<<"
echo "Los logs se guardaran en temp/docker-build/logs/build_docker.log, patch_libs.log y build_libs.log"

export DOCKER_BUILDKIT=1
if docker build --progress=plain -t javiermk/vidra-ffmpeg:latest -f Dockerfile . > temp/docker-build/logs/build_docker.log 2>&1; then
    echo "Docker build completado exitosamente!"
    # Extraer logs desde la imagen generada
    docker run --rm javiermk/vidra-ffmpeg:latest cat /logs/patch_libs.log > temp/docker-build/logs/patch_libs.log || true
    docker run --rm javiermk/vidra-ffmpeg:latest cat /logs/build_libs.log > temp/docker-build/logs/build_libs.log || true
    docker image prune -f > /dev/null 2>&1
else
    echo "Error en el Docker build! Revisa temp/docker-build/logs/build_docker.log"
    exit 1
fi
