#!/bin/bash

export FFMPEG_VERSION=8.0.1
export EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (All en libraries.md)
export LIBS_COMMON="x264 zlib openssl libxml2 freetype harfbuzz fribidi libass libmp3lame opus libdav1d libvpx libwebp libopenjpeg zimg libsoxr"

# Extras Linux
export LIBS_LINUX="fontconfig libx265 libsvtav1 libsnappy libssh libvpl vaapi vulkan opencl nvcodec"

# Extras Android
export LIBS_ANDROID="mediacodec jni"

# Extras Windows
export LIBS_WINDOWS="schannel fontconfig libx265 libsvtav1 libsnappy libssh libvpl nvcodec dxva2 d3d11va"

# ABI soportado (uno a la vez): armeabi-v7a | arm64-v8a | x86 | x86_64.
export ANDROID_ABI="armeabi-v7a"
