#!/bin/bash
set -euo pipefail

TARGET=${1:-}

echo "Usando configuración en /build/config.sh; pasa target (windows|linux|android)."

if [ "$TARGET" == "windows" ]; then
    source /build/scripts/platforms/windows.sh
    build_windows
elif [ "$TARGET" == "linux" ]; then
    source /build/scripts/platforms/linux.sh
    build_linux
elif [ "$TARGET" == "android" ]; then
    source /build/scripts/platforms/android.sh
    build_android
else
    echo "Error: Debes especificar target (windows|linux|android)"
    exit 1
fi