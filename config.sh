FFMPEG_VERSION=8.0.1
EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (cruzadas y ya soportadas en Android/Linux/Windows)
LIBS_COMMON="x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi fontconfig libass libmp3lame opus libvorbis twolame libdav1d libvpx libwebp libopenjpeg zimg libsoxr"

# Extras específicos de Linux (aceleración y códecs/filtros ampliados)
LIBS_LINUX="libvmaf libplacebo chromaprint frei0r libsnappy libx265 libsvtav1 libssh vaapi vulkan opencl libvpl nvcodec"

# Extras específicos de Android (solo los que tenemos recetas y toolchain probada)
LIBS_ANDROID="mediacodec jni"

# Librerías específicas de Windows (alineadas con MSYS2 estático; sin libplacebo)
LIBS_WINDOWS="dxva2 d3d11va schannel libx265 libsvtav1 chromaprint libssh libsnappy"

# arm arm-v7n armv7-a armeabi-v7a arm64-v8a i686 x86 x86_64 native "armeabi-v7a arm64-v8a x86 x86_64"
ANDROID_ABIS="x86_64"
