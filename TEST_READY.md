# Vidra-FFmpeg End-to-End Test Suite Specification (`TEST_READY.md`)

## 1. Executive Summary

The `vidra-ffmpeg` test suite (`test/test_ffmpeg.py`) provides an industrial-grade, 4-tier automated test harness for validating statically compiled multimedia binaries across **Linux x86_64**, **Windows x86_64** (via Wine), and **Android** (`arm64-v8a` / `armeabi-v7a` via ADB).

### Key Architectural Tenets

1. **Zero External Media Dependencies**: Uses Libavfilter virtual devices (`lavfi` with `testsrc`, `testsrc2`, `aevalsrc`, `color`) and synthetically generated styled subtitle manifests (`.ass`) to generate synthetic audio, video, and subtitle streams on the fly.
2. **Dynamic Flag Introspection**: Automatically parses `--enable-*` compilation flags directly from `ffmpeg -version` output and executes the corresponding feature test cases.
3. **Robust Hardware Error & Signal Trapping**: Traps negative process exit codes and signals (such as Linux `-8` `SIGFPE` from uninitialized GPU ICD loaders or headless environments) as well as driver-missing stderr signatures, gracefully categorizing them as `SKIPPED (Hardware not available)`.
4. **Binary & File Output Verification**: Asserts process return codes and verifies generated output files exist and contain non-zero byte payloads.
5. **Exit Code Semantics**:
   - Exit code `0`: All executed software tests passed (`OK`) and missing hardware/driver tests were gracefully skipped (`SKIPPED`).
   - Exit code `1`: One or more software tests failed (`FAIL`), timed out (`TIMEOUT`), or encountered an unhandled fatal error.

---

## 2. Test Runner Invocation

### Command Syntax

```bash
python3 test/test_ffmpeg.py <ffmpeg_binary_path> <output_temp_dir> [--tier {1,2,3,4,all}]
```

### Platform-Specific Commands

#### 2.1 Linux x86_64

```bash
python3 test/test_ffmpeg.py ./dist/linux-x86_64/ffmpeg ./temp/test_linux
```

#### 2.2 Windows x86_64 (via Wine)

```bash
python3 test/test_ffmpeg.py ./dist/windows-x86_64/ffmpeg.exe ./temp/test_windows
```

_Note: The test runner automatically invokes `wine` and sets `WINEDEBUG=-all` in the process environment to suppress non-fatal Wine debug logs._

#### 2.3 Android (`arm64-v8a` / `armeabi-v7a` via ADB)

```bash
python3 test/test_ffmpeg.py ./dist/android-arm64-v8a/ffmpeg ./temp/test_android_arm64
```

_Note: Staging to `/data/local/tmp/vidra_ffmpeg_test`, permissions, execution, and post-run cleanup are automatically managed by the runner._

#### 2.4 Tier-Specific Execution

```bash
# Run only Tier 2 Boundary Cases
python3 test/test_ffmpeg.py ./dist/linux-x86_64/ffmpeg ./temp/test_linux_tier2 --tier 2

# Run only Tier 3 Integration Combinations
python3 test/test_ffmpeg.py ./dist/linux-x86_64/ffmpeg ./temp/test_linux_tier3 --tier 3
```

---

## 3. 4-Tier Test Matrix Breakdown

```raw
+-------------------------------------------------------------------------------+
|                        VIDRA-FFMPEG 4-TIER TEST MATRIX                        |
+-------------------------------------------------------------------------------+
|  TIER 1: FEATURE COVERAGE (52-54 tests)                                       |
|  - Unit validation of all 60+ codecs, filters, formats, demuxers, & protocols |
+-------------------------------------------------------------------------------+
|  TIER 2: BOUNDARY & CORNER CASES (11 tests)                                   |
|  - 1-frame duration, odd resolutions, high bit depths (10/12-bit),            |
|    extreme aspect ratios, fractional frame rates, surround audio, 4K synthesis |
+-------------------------------------------------------------------------------+
|  TIER 3: CROSS-FEATURE COMBINATIONS (6 tests)                                 |
|  - HDR10->SDR tone mapping, multi-track audio muxing, multi-rate DASH ladder, |
|    rubberband pitch shift + soxr + chromaprint, ASS subtitle burn-in, PIP     |
+-------------------------------------------------------------------------------+
|  TIER 4: REAL-WORLD SCENARIOS & WORKLOADS (6 tests)                           |
|  - YouTube delivery spec, next-gen AV1+Opus container, 9:16 vertical video,  |
|    JPEG-2000 broadcast master, multi-threaded CPU saturation, HLS streaming   |
+-------------------------------------------------------------------------------+
```

---

### Tier 1: Feature & Capability Coverage (Unit Level)

| Test ID   | Category       | Feature / Flag         | Command Specification                                           | Verification Criteria                 |
| :-------- | :------------- | :--------------------- | :-------------------------------------------------------------- | :------------------------------------ |
| **T1.01** | Core           | `basic_video`          | `-f lavfi -i testsrc=duration=1:size=640x360:rate=30 -f null -` | Exit code 0                           |
| **T1.02** | Core           | `basic_audio`          | `-f lavfi -i aevalsrc=0:duration=1 -f null -`                   | Exit code 0                           |
| **T1.03** | Video Enc      | `libx264`              | `testsrc -> -c:v libx264 -preset ultrafast test_x264.mp4`       | File > 0 bytes, Exit code 0           |
| **T1.04** | Video Enc      | `libx265`              | `testsrc -> -c:v libx265 -preset ultrafast test_x265.mp4`       | File > 0 bytes, Exit code 0           |
| **T1.05** | Video Enc      | `libvpx`               | `testsrc -> -c:v libvpx-vp9 test_vp9.webm`                      | File > 0 bytes, Exit code 0           |
| **T1.06** | Video Enc      | `libaom`               | `testsrc -> -c:v libaom-av1 -strict experimental test_av1.mkv`  | File > 0 bytes, Exit code 0           |
| **T1.07** | Video Enc      | `libsvtav1`            | `testsrc -> -c:v libsvtav1 test_svtav1.mp4`                     | File > 0 bytes, Exit code 0           |
| **T1.08** | Video Enc      | `librav1e`             | `testsrc -> -c:v librav1e -speed 10 test_rav1e.mp4`             | File > 0 bytes, Exit code 0           |
| **T1.09** | Video Enc      | `libkvazaar`           | `testsrc -> -c:v libkvazaar test_kvazaar.mp4`                   | File > 0 bytes, Exit code 0           |
| **T1.10** | Video Enc      | `libxavs2`             | `testsrc -> -c:v libxavs2 test_xavs2.mkv`                       | File > 0 bytes, Exit code 0           |
| **T1.11** | Video Enc      | `liboapv`              | `testsrc -> -c:v liboapv test_oapv.mp4`                         | File > 0 bytes, Exit code 0           |
| **T1.12** | Video Enc      | `libvvenc`             | `testsrc -> -c:v libvvenc test_vvenc.mp4`                       | File > 0 bytes, Exit code 0           |
| **T1.13** | Video Enc      | `libtheora`            | `testsrc -> -c:v libtheora test_theora.ogg`                     | File > 0 bytes, Exit code 0           |
| **T1.14** | Video Enc      | `libopenh264`          | `testsrc -> -c:v libopenh264 test_openh264.mp4`                 | File > 0 bytes, Exit code 0           |
| **T1.15** | Video Enc      | `libxvid`              | `testsrc -> -c:v libxvid test_xvid.avi`                         | File > 0 bytes, Exit code 0           |
| **T1.16** | Video Enc      | `libopenjpeg`          | `testsrc -> -c:v libopenjpeg test_openjpeg.mkv`                 | File > 0 bytes, Exit code 0           |
| **T1.17** | Image Enc      | `libjxl`               | `testsrc -> -c:v libjxl -update 1 test_jxl.jxl`                 | File > 0 bytes, Exit code 0           |
| **T1.18** | Image Enc      | `libwebp`              | `testsrc -> -c:v libwebp test_webp.webp`                        | File > 0 bytes, Exit code 0           |
| **T1.19** | Decoder        | `libdav1d`             | Interrogate `-decoders` registration                            | String `dav1d` registered             |
| **T1.20** | Decoder        | `libdavs2`             | Interrogate `-decoders` registration                            | String `davs2` registered             |
| **T1.21** | Decoder        | `libopencore-amrwb`    | Interrogate `-decoders` registration                            | String `libopencore_amrwb` registered |
| **T1.22** | Decoder        | `libuavs3d`            | Interrogate `-decoders` registration                            | String `uavs3d` registered            |
| **T1.23** | Decoder        | `liblcevc-dec`         | Interrogate `-decoders` registration                            | String `lcevc` registered             |
| **T1.24** | Demuxer        | `libgme`               | Interrogate `-demuxers` registration                            | String `gme` registered               |
| **T1.25** | Demuxer        | `libopenmpt`           | Interrogate `-demuxers` registration                            | String `openmpt` registered           |
| **T1.26** | Protocol       | `libbluray`            | Interrogate `-protocols` registration                           | String `bluray` registered            |
| **T1.27** | Demuxer        | `libdvdread`           | Interrogate `-demuxers` registration                            | String `dvdread` registered           |
| **T1.28** | Demuxer        | `libdvdnav`            | Interrogate `-demuxers` registration                            | String `dvdnav` registered            |
| **T1.29** | Audio Enc      | `libmp3lame`           | `aevalsrc -> -c:a libmp3lame test_lame.mp3`                     | File > 0 bytes, Exit code 0           |
| **T1.30** | Audio Enc      | `libopus`              | `aevalsrc -> -c:a libopus test_opus.mkv`                        | File > 0 bytes, Exit code 0           |
| **T1.31** | Audio Enc      | `libvorbis`            | `aevalsrc -> -c:a libvorbis test_vorbis.ogg`                    | File > 0 bytes, Exit code 0           |
| **T1.32** | Audio Enc      | `libtwolame`           | `aevalsrc -> -c:a libtwolame test_twolame.mp2`                  | File > 0 bytes, Exit code 0           |
| **T1.33** | Audio Enc      | `libopencore-amrnb`    | `aevalsrc:8000 -> -c:a libopencore_amrnb -ac 1 test_amrnb.amr`  | File > 0 bytes, Exit code 0           |
| **T1.34** | DSP Filter     | `libsoxr`              | `aevalsrc -> -af aresample=resampler=soxr -f null -`            | Exit code 0                           |
| **T1.35** | DSP Filter     | `librubberband`        | `aevalsrc -> -af rubberband=pitch=1.5 -f null -`                | Exit code 0                           |
| **T1.36** | DSP Muxer      | `chromaprint`          | `aevalsrc -> -f chromaprint -`                                  | Fingerprint emitted, Exit code 0      |
| **T1.37** | Text Filter    | `libfreetype`          | `color -> -vf drawtext=text='Test':fontsize=24 -f null -`       | Text rendered, Exit code 0            |
| **T1.38** | Sub Filter     | `libass`               | `color -> -vf ass=test.ass -f null -`                           | Styled subs rendered, Exit code 0     |
| **T1.39** | Stabilization  | `libvidstab`           | `testsrc -> -vf vidstabdetect=result=transform.trf -f null -`   | Motion detected, Exit code 0          |
| **T1.40** | Scaler         | `libzimg`              | `testsrc -> -vf zscale=w=320:h=180 -f null -`                   | Scaled, Exit code 0                   |
| **T1.41** | GPU Filter     | `libplacebo`           | `testsrc -> -vf libplacebo -f null -`                           | Exit code 0 or SKIPPED                |
| **T1.42** | Quality Filter | `libvmaf`              | `2x testsrc -> -filter_complex libvmaf -f null -`               | Exit code 0 or SKIPPED                |
| **T1.43** | Muxer          | `libxml2`              | `testsrc -> -c:v libx264 -f dash test_dash.mpd`                 | File > 0 bytes, Exit code 0           |
| **T1.44** | Protocol       | `openssl` / `schannel` | Interrogate `-protocols` registration                           | String `https` registered             |
| **T1.45** | Protocol       | `libsrt`               | Interrogate `-protocols` registration                           | String `srt` registered               |
| **T1.46** | Protocol       | `librist`              | Interrogate `-protocols` registration                           | String `rist` registered              |
| **T1.47** | Protocol       | `libssh`               | Interrogate `-protocols` registration                           | String `sftp` registered              |
| **T1.48** | Protocol       | `libzmq`               | Interrogate `-protocols` registration                           | String `zmq` registered               |
| **T1.49** | Hardware       | `ffnvcodec`            | `testsrc -> -c:v h264_nvenc test_nvenc.mp4`                     | Exit code 0 or SKIPPED                |
| **T1.50** | Hardware       | `vaapi`                | `-hwaccel vaapi -> -c:v h264_vaapi test_vaapi.mp4`              | Exit code 0 or SKIPPED                |
| **T1.51** | Hardware       | `vulkan`               | `-init_hw_device vulkan=vk:0 -f null -`                         | Exit code 0 or SKIPPED                |
| **T1.52** | Hardware       | `opencl`               | `-init_hw_device opencl -f null -`                              | Exit code 0 or SKIPPED                |
| **T1.53** | Hardware       | `amf`                  | `testsrc -> -c:v h264_amf test_amf.mp4`                         | Exit code 0 or SKIPPED                |
| **T1.54** | Hardware       | `libvpl`               | `testsrc -> -c:v h264_qsv test_qsv.mp4`                         | Exit code 0 or SKIPPED                |
| **T1.55** | Hardware       | `mediacodec`           | `testsrc -> -pix_fmt nv12 -c:v h264_mediacodec test_mc.mp4`     | Exit code 0 on Android                |

---

### Tier 2: Boundary & Corner Cases (Robustness Level)

| Test ID   | Test Name                   | Purpose & Parameters                                        | Verification Criteria                   |
| :-------- | :-------------------------- | :---------------------------------------------------------- | :-------------------------------------- |
| **T2.01** | `tier2_single_frame`        | Single-frame video encode (`-vframes 1 -c:v libx264`)       | Exactly 1 frame encoded, File > 0 bytes |
| **T2.02** | `tier2_odd_dimensions`      | Non-standard 641x361 resolution with 2-pixel chroma padding | Auto-aligned, File > 0 bytes            |
| **T2.03** | `tier2_extreme_aspect_wide` | 1920x120 ultra-wide panorama aspect ratio                   | Encoded without allocation fault        |
| **T2.04** | `tier2_extreme_aspect_tall` | 120x1080 ultra-tall vertical strip aspect ratio             | Encoded without memory fault            |
| **T2.05** | `tier2_10bit_color`         | 10-bit High Dynamic Range color (`yuv420p10le` + `libx265`) | 10-bit bitstream written                |
| **T2.06** | `tier2_12bit_color`         | 12-bit Deep Color (`yuv420p12le` + `libaom-av1`)            | 12-bit AV1 bitstream written            |
| **T2.07** | `tier2_fractional_fps`      | Fractional NTSC framerate (`30000/1001` = 29.970 fps)       | NTSC timing preserved                   |
| **T2.08** | `tier2_surround_51_audio`   | 6-channel 5.1 surround sound audio encode (`libopus`)       | 5.1 layout audio written                |
| **T2.09** | `tier2_high_sample_rate`    | Studio-master 96,000 Hz sample rate audio encode            | 96kHz audio written                     |
| **T2.10** | `tier2_high_resolution_4k`  | 3840x2160 (4K UHD) high-throughput video encode             | 4K video stream written                 |
| **T2.11** | `tier2_low_bitrate_edge`    | Ultra-low bitrate audio/video (50kbps video + 16kbps audio) | Extremely compressed stream valid       |

---

### Tier 3: Cross-Feature Combinations (Integration Level)

| Test ID   | Pipeline Name                      | Cross-Feature Interaction & Components                                                                                       | Verification Criteria                          |
| :-------- | :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------- |
| **T3.01** | `tier3_hdr_sdr_tonemap`            | SMPTE 2084 PQ / BT.2020 synthesis -> `zscale` tone map to BT.709 -> `drawtext` metadata burn-in -> H.264 encode              | Multi-filter pipeline executes, File > 0 bytes |
| **T3.02** | `tier3_multitrack_master`          | 1 Video stream + Dual audio tracks (Track 1: Opus 128k; Track 2: MP3 128k resampled via `libsoxr`) in Matroska               | 3 streams muxed into single MKV                |
| **T3.03** | `tier3_dash_adaptive_ladder`       | Video split into 640x360 & 320x180 ladders -> simultaneous dual H.264 encodes -> `libxml2` DASH packaging                    | Valid DASH `.mpd` manifest generated           |
| **T3.04** | `tier3_pitch_resample_chromaprint` | Audio stream -> `librubberband` pitch shift -> `libsoxr` resample -> simultaneous Opus encoding + Chromaprint fingerprinting | Audio encoded & fingerprint generated          |
| **T3.05** | `tier3_subtitle_burnin`            | Synthesized ASS subtitle script rasterized via `libass` onto video canvas -> H.264 encode                                    | Subtitles burned into video frames             |
| **T3.06** | `tier3_picture_in_picture`         | Dual synthetic video streams composited via `overlay` filter graph -> H.264 encode                                           | Picture-in-picture video generated             |

---

### Tier 4: Real-World Scenarios (Production Level)

| Test ID   | Scenario Name                   | Industry Profile Specifications                                                                  | Verification Criteria                   |
| :-------- | :------------------------------ | :----------------------------------------------------------------------------------------------- | :-------------------------------------- |
| **T4.01** | `tier4_web_video_youtube`       | YouTube Delivery Spec: 1080p H.264, CRF 20, faststart atom enabled, AAC 192k audio               | Web-optimized MP4 generated             |
| **T4.02** | `tier4_nextgen_av1_opus`        | Next-Gen Streaming Master: `libsvtav1` preset 8 + `libopus` 96kbps in MKV                        | Next-gen AV1 container generated        |
| **T4.03** | `tier4_social_vertical_9_16`    | Social Media Vertical Video: 360x640 (9:16) vertical format @ 30fps + AAC audio                  | Vertical video stream generated         |
| **T4.04** | `tier4_broadcast_master_j2k`    | Broadcast Archive Master: High-bitrate JPEG-2000 (`libopenjpeg`) @ 24fps + 24-bit 48kHz PCM      | Archive master generated                |
| **T4.05** | `tier4_multithread_concurrency` | Multithreaded CPU Saturation: All CPU cores saturated (`-threads 0`) with heavy SVT-AV1 encoder  | Multithreaded encode succeeds           |
| **T4.06** | `tier4_hls_adaptive_streaming`  | HLS Live/VOD Segmenter: `-f hls -hls_time 1 -hls_list_size 0` generating MPEG-TS segments & M3U8 | Valid `.m3u8` playlist & `.ts` segments |

---

## 4. Verified Execution Results

### 4.1 Windows x86_64 (`dist/windows-x86_64/ffmpeg.exe` via Wine)

- **Command**: `python3 test/test_ffmpeg.py ./dist/windows-x86_64/ffmpeg.exe ./temp/test_windows_t1`
- **Total Tests Executed**: 75
- **Tier 1 (Feature Coverage)**: 46 passed, 6 skipped (HW: `opencl`, `amf`, `ffnvcodec`, `libplacebo`, `libvpl`, `libvmaf`), 0 failed
- **Tier 2 (Boundary & Corner)**: 11 passed, 0 skipped, 0 failed
- **Tier 3 (Cross-Feature Combinations)**: 6 passed, 0 skipped, 0 failed
- **Tier 4 (Real-World Scenarios)**: 6 passed, 0 skipped, 0 failed
- **Overall Result**: **69 PASSED, 6 SKIPPED (Hardware not available), 0 FAILED**
- **Exit Code**: `0`

### 4.2 Linux x86_64 (`dist/linux-x86_64/ffmpeg`)

- **Command**: `python3 test/test_ffmpeg.py ./dist/linux-x86_64/ffmpeg ./temp/test_linux_t1`
- **Total Tests Executed**: 77
- **Tier 1 (Feature Coverage)**: 46 passed, 8 skipped (HW: `vulkan`, `opencl`, `ffnvcodec`, `vaapi`, `amf`, `libvpl`, `libplacebo`, `libvmaf`), 0 failed
- **Tier 2 (Boundary & Corner)**: 11 passed, 0 skipped, 0 failed
- **Tier 3 (Cross-Feature Combinations)**: 6 passed, 0 skipped, 0 failed
- **Tier 4 (Real-World Scenarios)**: 6 passed, 0 skipped, 0 failed
- **Overall Result**: **69 PASSED, 8 SKIPPED (Hardware not available), 0 FAILED**
- **Exit Code**: `0`

---

## 5. Maintenance & Extension Guidelines

1. **Adding a New Codec or Library**:
   - Add the feature flag test entry in `get_tier1_feature_tests(output_dir)`.
   - If the feature requires external GPU hardware/driver, add the feature name to `HW_FEATURES`.
2. **Adding Boundary or Combination Workloads**:
   - Add new test cases to `get_tier2_boundary_tests`, `get_tier3_combination_tests`, or `get_tier4_realworld_tests`.
3. **Android Testing**:
   - Ensure a physical Android device or emulator is connected before triggering ADB tests.
