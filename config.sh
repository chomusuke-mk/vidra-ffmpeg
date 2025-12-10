FFMPEG_VERSION=8.0.1
EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (All en libraries.md)
LIBS_COMMON="x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi libass libmp3lame opus libdav1d libvpx libwebp libopenjpeg zimg libsoxr"

# Extras Linux (solo Linux en libraries.md o compartidas Windows|Linux)
LIBS_LINUX="fontconfig libx265 libsvtav1 libsnappy libssh libvpl vaapi vulkan opencl nvcodec"

# Extras Android (solo Android en libraries.md)
LIBS_ANDROID="mediacodec jni"

# Extras Windows (solo Windows en libraries.md o compartidas Windows|Linux)
LIBS_WINDOWS="schannel dxva2 d3d11va fontconfig libx265 libsvtav1 libsnappy libssh libvpl nvcodec"

# arm arm-v7n armv7-a armeabi-v7a arm64-v8a i686 x86 x86_64 native "armeabi-v7a arm64-v8a x86 x86_64"
ANDROID_ABIS="x86_64"
