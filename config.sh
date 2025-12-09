FFMPEG_VERSION=8.0.1
EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (cruzadas y ya soportadas en Android/Linux/Windows)
LIBS_COMMON="x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi fontconfig libass libmp3lame opus libvorbis twolame libaom libdav1d libvpx libwebp libopenjpeg zimg libsoxr librubberband libvidstab libsrt"

# Extras específicos de Linux (aceleración y códecs/filtros ampliados)
LIBS_LINUX="libvmaf libplacebo librist libzmq chromaprint frei0r libsnappy libzvbi libbluray libdvdread libdvdnav libaribcaption libaribb24 libx265 libsvtav1 librav1e libxvid libtheora openh264 libssh vaapi vdpau vulkan libshaderc opencl libvpl nvcodec"

# Extras específicos de Android (solo los que tenemos recetas y toolchain probada)
LIBS_ANDROID="mediacodec jni"

# Librerías específicas de Windows (alineadas con MSYS2 estático; sin libplacebo)
LIBS_WINDOWS="dxva2 d3d11va schannel libx265 libsvtav1 librav1e libxvid libtheora chromaprint librist libzmq libsnappy libzvbi libbluray libdvdread libdvdnav openh264 libssh"

# arm arm-v7n armv7-a armeabi-v7a arm64-v8a i686 x86 x86_64 native "armeabi-v7a arm64-v8a x86 x86_64"
ANDROID_ABIS="x86_64"
