# Libraries used for yt-dlp-optimized FFmpeg builds

This table documents the libraries enabled via `config.sh`, what they provide, and where se usan (OS/arquitectura) para builds optimizados para yt-dlp.

| Library            | Purpose / functionality             | Why (yt-dlp / stability / accel)            | OS / accel scope                      | Notas (licencia / empaquetado) |
| ------------------ | ----------------------------------- | ------------------------------------------- | ------------------------------------- | -------------------------------- |
| x264               | H.264 encoder/decoder               | Re-encode/transcode                         | All                                   | GPL                              |
| libx265            | H.265 encoder/decoder               | HEVC re-encode                              | Linux, Windows                        | GPL                              |
| libsvtav1          | AV1 encoder                         | Faster AV1 encoding                         | Linux, Windows                        | BSD                              |
| libdav1d           | AV1 decoder                         | Fast AV1 decode                             | All                                   | BSD                              |
| libvpx             | VP8/VP9 codec                       | WebM decode/encode                          | All                                   | BSD                              |
| zlib               | Compressed streams                  | DASH/HLS gzip                               | All                                   | Zlib                             |
| brotli             | Brotli manifests                    | DASH/HLS Brotli                             | All                                   | MIT                              |
| openssl            | TLS/HTTPS                           | Robust HTTP(S)/HLS                          | All (except Windows usa schannel)     | Apache-2                          |
| schannel           | TLS backend nativo                  | HTTPS en Windows                            | Windows                               | MIT                              |
| libxml2            | XML parsing                         | DASH manifests                              | All                                   | MIT                              |
| freetype           | Font rasterization                  | Subtítulos (libass)                         | All                                   | FTL/GPL                           |
| harfbuzz           | Text shaping                        | Subtítulos (libass)                         | All                                   | MIT                              |
| fribidi            | Bidirectional text                  | Subtítulos (libass)                         | All                                   | LGPL                             |
| fontconfig         | Font discovery                      | Subtítulos (libass)                         | All                                   | MIT                              |
| libass             | ASS/SSA render/burn                 | yt-dlp subtítulos                           | All                                   | ISC                              |
| libmp3lame         | MP3 encoding                        | Postprocess transcodes                      | All                                   | LGPL/GPL                          |
| opus               | Opus codec                          | Web audio decode/encode                     | All                                   | BSD                              |
| libvorbis          | Vorbis codec                        | Web/ogg audio                               | All                                   | BSD                              |
| libwebp            | WebP images                         | Thumbnails                                  | All                                   | BSD                              |
| libopenjpeg        | JPEG 2000 decode                    | Container edge cases                        | All                                   | BSD                              |
| zimg               | HQ colorspace/resize                | Filters (scaling)                           | All                                   | GPL                              |
| libsoxr            | HQ resampler                        | Audio resampling                            | All                                   | LGPL                             |
| libsnappy          | Compression                         | Container/codecs support                    | Linux, Windows                        | BSD                              |
| libssh             | SFTP over SSH                       | Network IO                                  | Linux, Windows                        | LGPL                             |
| libvpl             | Intel oneVPL                        | HW accel                                     | Linux                                 | Apache-2                          |
| vaapi              | GPU decode/encode (Intel/AMD)       | HW acceleration                             | Linux                                 | MIT                              |
| vulkan             | GPU pipeline                        | HW acceleration                             | Linux                                 | Apache-2                          |
| opencl             | GPU compute filters                 | HW acceleration                             | Linux                                 | Apache-2                          |
| nvcodec            | NVENC/NVDEC                         | HW acceleration                             | Linux                                 | MIT                              |
| dxva2              | HW video decode                     | HW acceleration                             | Windows                               | MIT                              |
| d3d11va            | HW video decode                     | HW acceleration                             | Windows                               | MIT                              |
| mediacodec/jni     | Android HW decode                   | HW acceleration                             | Android                               | NDK                              |

Notes:

- `LIBS_COMMON` aplica a todos los targets; `LIBS_LINUX`/`LIBS_WINDOWS` se añaden por OS en `collect_target_libs`. `LIBS_ANDROID` agrega extras Android.
