# Hardware acceleration libs unused by default yt-dlp

Based on `libraries.md`, yt-dlp's README, and code in `.venv/Lib/site-packages/yt_dlp` (no `hwaccel`/`nvenc`/`vaapi`/`dxva` references in the codebase), the following hardware acceleration libraries are not exercised by yt-dlp with default options. yt-dlp invokes ffmpeg only for merging/remuxing/transcoding and never adds hardware flags unless the user customizes ffmpeg args.

- libvpl (Intel oneVPL) – HW accel not invoked by default CLI
- vaapi – VA-API decode/encode not used by default
- vulkan – GPU pipeline not touched by default
- opencl – GPU compute filters not requested by default
- nvcodec (NVENC/NVDEC) – No hwaccel/encoder selection by default
- dxva2 – Windows decode accel not used by default
- d3d11va – Windows decode accel not used by default
- mediacodec/jni – Android HW decode not used by default
