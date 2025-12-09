# Libraries used for yt-dlp-optimized FFmpeg builds

This table documents the libraries enabled via `config.sh`, what they provide, and why they are included.

| Library            | Purpose / functionality        | Why (yt-dlp / stability / accel)           |
| ------------------ | ------------------------------ | ------------------------------------------ |
| x264               | H.264 encoder/decoder          | yt-dlp re-encode/transcode option          |
| zlib               | Compressed streams, HTTP gzip  | yt-dlp DASH/HLS manifests often compressed |
| brotli             | Compressed manifests (Brotli)  | yt-dlp DASH/HLS on some CDNs               |
| openssl            | TLS/HTTPS, modern ciphers      | Required for robust HTTP(S)/HLS/DASH       |
| libxml2            | XML parsing for DASH manifests | yt-dlp DASH handling                       |
| freetype           | Font rasterization             | Subtitle rendering (libass)                |
| harfbuzz           | Text shaping                   | Subtitle rendering (libass)                |
| fribidi            | Bidirectional text             | Subtitle rendering (libass)                |
| fontconfig         | Font discovery                 | Subtitle rendering (libass)                |
| libass             | ASS/SSA subtitles render/burn  | yt-dlp subtitle burn/convert               |
| libmp3lame         | MP3 encoding                   | yt-dlp postprocessing transcodes           |
| opus               | Opus codec                     | Decode/encode web audio, webm/opus         |
| libvorbis          | Vorbis codec                   | Decode/encode vorbis, webm/ogg             |
| twolame            | MP2 audio encoder              | Legacy/remux cases                         |
| libaom             | AV1 codec (encode/decode)      | Optional re-encode/transcode               |
| libdav1d           | AV1 decoder                    | Playback/merge AV1 streams                 |
| libvpx             | VP8/VP9 codec                  | WebM video decode/encode                   |
| libwebp            | WebP images                    | Thumbnails/cover art parsing               |
| libopenjpeg        | JPEG 2000 decode               | Container edge cases                       |
| zimg               | High-quality colorspace/resize | Filters (scaling/conversion)               |
| libvmaf            | VMAF quality filter            | Optional quality metrics                   |
| libplacebo         | GPU-accelerated filters        | Improved rendering/filters                 |
| libsoxr            | High-quality resampler         | Audio resampling                           |
| librubberband      | Time-stretch/pitch             | Audio filters                              |
| libvidstab         | Video stabilization            | Optional filter use                        |
| libsrt             | Secure Reliable Transport      | Network ingest (if present)                |
| vaapi (Linux)      | GPU decode/encode (Intel/AMD)  | HW acceleration                            |
| vulkan (Linux)     | GPU pipeline support           | HW acceleration                            |
| libshaderc (Linux) | SPIR-V compilation             | GPU filter support                         |
| opencl (Linux)     | GPU compute filters            | HW acceleration                            |
| libvpl (Linux)     | Intel oneVPL                   | HW acceleration                            |
| nvcodec (Linux)    | NVIDIA NVENC/NVDEC             | HW acceleration                            |
| dxva2 (Windows)    | HW video decode                | HW acceleration                            |
| d3d11va (Windows)  | HW video decode                | HW acceleration                            |
| schannel (Windows) | Native TLS backend             | HTTPS on Windows                           |

Notes:

- `LIBS_COMMON` applies to all targets; `LIBS_LINUX`/`LIBS_WINDOWS` are appended per OS by `collect_target_libs`.
- GPU accel is kept per-OS where available.
