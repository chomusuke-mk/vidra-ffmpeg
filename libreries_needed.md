# FFmpeg features needed for optimal yt-dlp use

This checklist distills what yt-dlp expects from FFmpeg to work correctly across all extractors, containers, and post-processing steps. It is based on the official yt-dlp FFmpeg-Builds README plus yt-dlp’s own options and common site formats.

## Protocols and inputs

- HTTP/HTTPS with TLS (openssl/gnutls) including HTTP/2, cookies, gzip/deflate/brotli, redirects.
- HLS (`hls`, `hls+http`, `hls+https`) with AES-128/TS and fMP4 variants.
- DASH (`dash`, `dash+http`, `dash+https`) including XML manifests (needs libxml2/zlib/brotli if available).
- RTMP/RTMPS (`librtmp` or built-in rtmp protocol) for legacy live sites.
- File, concat, and tee protocols for merging/segmenting outputs.
- TLS SNI, OCSP, and modern ciphers (openssl preferred); IDN via libidn2 is a plus.

## Demuxers/parsers

- `matroska`, `mp4`/`mov`, `m4a`, `webm`, `flv`, `ts`, `m3u8`, `dash`, `ogg`, `wav`, `aac`, `mp3`, `flac`, `caf`, `avi`.
- Subtitle demuxers: `webvtt`, `ass`, `srt`, `ttml`, `mov_text`, `dvdsub`, `pgssub` (for passthrough where present).

## Muxers (yt-dlp output targets)

- `mp4`/`mov` (with faststart), `matroska`/`webm`, `m4a`, `ogg`, `opus`, `flac`, `ts`, `segment`/`ssegment`, `fmp4` (for HLS/DASH fragments), `concat`, `null` (for probe-only), `srt`, `ass`, `webvtt`.

## Codecs and bitstream filters

- Video decoders: `h264`, `hevc`, `vp9`, `av1`, `mpeg4`, `mpeg2video`, `flv1`.
- Audio decoders: `aac` (and LATM), `mp3`, `opus`, `vorbis`, `flac`, `alac`, `wavpack`, `ac3`/`eac3`, `pcm*`.
- Subtitle decoders: `mov_text`, `ass`, `webvtt`, `srt`.
- Encoders commonly needed for remux/convert steps: `aac` (native), `libmp3lame`, `libopus`, `libvorbis`, `flac`, `libx264` (when user re-encodes), `libvpx-vp9`/`libaom-av1` optional but useful.
- Bitstream filters: `aac_adtstoasc` (HLS to MP4), `h264_mp4toannexb`/`hevc_mp4toannexb` (TS/HLS), `vp9_superframe`.

## Subtitles and attachments

- Converters: `srt`, `ass`, `webvtt`, `mov_text` for muxing into MP4/MKV.
- Attachment/metadata handling for fonts (ASS) when remuxing MKV; requires `libass`/`freetype` to burn subs when requested.

## Filters commonly used by yt-dlp post-processors

- `scale`, `subtitles`/`ass` (needs libass), `aresample`, `asetpts`/`setpts`, `atrim`/`trim`, `format`/`aformat`, `fps`, `copy` passthrough.

## Patches noted by yt-dlp FFmpeg-Builds

- Already upstream as of FFmpeg 8.0: AAC HLS truncation fix, VP9 non-monotonous DTS fix, Windows long-path support, chapter embedding regression fix, WebVTT decode fix, Vulkan NULL type fix, HEVC-in-FLV parsing fix.
- Open issues they welcome patches for: macOS builds, removing pre-first-subtitle segments (FFmpeg#9646), long HLS playlist support (FFmpeg#7673).

## Build-time options to double-check

- `--enable-protocol=https,hls,dash,file,concat,tee,rtmp,rtmps` (or `--enable-protocol=all` in static builds).
- `--enable-demuxer=matroska,mp4,mov,flv,mpegts,dash,hls,ogg,webvtt` and similar for muxers listed above (or `--enable-demuxer=all --enable-muxer=all` if size permits).
- `--enable-parser=aac,h264,hevc,vorbis,opus,flac,vp9,av1`.
- `--enable-libxml2 --enable-zlib --enable-brotli` for DASH/HLS manifests that use compression.
- `--enable-openssl` (or gnutls) for robust HTTPS.
- `--enable-libass --enable-libfreetype --enable-libfribidi --enable-libharfbuzz` for subtitle rendering/burning.
- `--enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libx264 --enable-libvpx --enable-libaom` to match yt-dlp’s optional re-encode/transcode postprocessors.

## Minimal vs optimal

- Minimal (merge-only): protocols above, demuxers/muxers above, native AAC/MP3/Opus/Vorbis/FLAC decoders, `aac_adtstoasc` bsf, and `--enable-openssl`.
- Optimal (mirrors yt-dlp prebuilt bundles): all of the above plus libass/freetype/fribidi/harfbuzz, zlib/brotli/libxml2, full muxer/demuxer sets, and common external encoders (lame/opus/vorbis/x264/vpx/aom).
