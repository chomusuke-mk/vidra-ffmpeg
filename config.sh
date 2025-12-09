FFMPEG_VERSION=8.0.1
EXTRA_VERSION="vidra_build-chomusuke.dev"

# Librerías comunes (se suman a cada OS): universales y útiles para yt-dlp
LIBS_COMMON="x264 zlib brotli openssl libxml2 freetype harfbuzz fribidi fontconfig libass libmp3lame opus libvorbis twolame libaom libdav1d libvpx libwebp libopenjpeg zimg libsoxr librubberband libvidstab libsrt"

# Extras específicos de Linux (aceleración y formatos desktop)
LIBS_LINUX="vaapi vulkan libshaderc opencl libvpl nvcodec"
LIBS_ANDROID="mediacodec jni"

# Librerías específicas de Windows (coinciden con paquetes MSYS2 descargados)
LIBS_WINDOWS="dxva2 d3d11va schannel"

# arm arm-v7n armv7-a armeabi-v7a arm64-v8a i686 x86 x86_64 native "armeabi-v7a arm64-v8a x86 x86_64"
ANDROID_ABIS="x86_64"
