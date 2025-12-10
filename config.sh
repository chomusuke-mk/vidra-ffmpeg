FFMPEG_VERSION=8.0.1
EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (All en libraries.md)
LIBS_COMMON="x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi libass libmp3lame opus libdav1d libvpx libwebp libopenjpeg zimg libsoxr"
# Librerías comunes adicionales (solo para build "full")
LIBS_COMMON_EXTENDED=""

# Extras Linux
LIBS_LINUX="fontconfig libx265 libsvtav1 libsnappy libssh"
LIBS_LINUX_EXTENDED="libvpl vaapi vulkan opencl nvcodec"

# Extras Android
LIBS_ANDROID=""
LIBS_ANDROID_EXTENDED="mediacodec jni"

# Extras Windows
LIBS_WINDOWS="schannel fontconfig libx265 libsvtav1 libsnappy libssh"
LIBS_WINDOWS_EXTENDED="libvpl nvcodec dxva2 d3d11va"

# arm arm-v7n armv7-a armeabi-v7a arm64-v8a i686 x86 x86_64 native "armeabi-v7a arm64-v8a x86 x86_64"
ANDROID_ABIS="x86_64"

# builds "full standard"
FFMPEG_BUILDS="full"