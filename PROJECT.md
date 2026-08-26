# Project: vidra-ffmpeg

## Architecture

- Multi-platform static multimedia processing engine based on FFmpeg `n8.1.2` with full software codec suite, next-generation video/image formats (AV1, VVC, AVS2/3, JPEG XL, APV), audio DSP/filters, hardware acceleration headers, and Android NDK MediaCodec integration.
- Full parity with reference `yt-dlp/FFmpeg-Builds`:
  - `libvmaf` built with `-Dbuilt_in_models=true -Denable_float=true` embedding model data directly into the static library.
  - `libplacebo` built with `libshaderc` support (`-Dshaderc=enabled -Dvulkan=enabled -Dvk-proc-addr=enabled -Dglslang=disabled`).
  - `dist/linux-x86_64/ffmpeg`: Static third-party libraries (.a) linked with standard glibc runtime (`libc.so.6`, `libdl.so.2`) allowing dynamic ICD/driver loading without glibc TLS crashes.
  - `dist/windows-x86_64/ffmpeg.exe`: Static MinGW-w64 cross-compilation validated via Wine.
  - `dist/android-arm64-v8a/ffmpeg` & `dist/android-armeabi-v7a/ffmpeg`: Static Android NDK builds with MediaCodec and static libc++.

## Feature Inventory

| #   | Feature / Library         | Description                                                                                                   | Target Platforms        | Assigned Milestone | Source                           |
| --- | ------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------- | ------------------ | -------------------------------- |
| 1   | `build_libs_isolation`    | Isolate environment variables in `build_libs.sh` across targets                                               | All                     | M1                 | Survey (Explorer 1)              |
| 2   | `view_files_validation`   | Validate patch application in `temp/patched` via `test/view_files.sh`                                         | All                     | M1                 | AGENTS.md / Survey               |
| 3   | `docker_build`            | Build Docker builder image cleanly with `docker compose --progress=plain build`                               | All                     | M1                 | AGENTS.md                        |
| 4   | `e2e_test_harness`        | Hardened 4-Tier E2E test harness (`test/test_ffmpeg.py`) with SIGFPE/HW trapping and `TEST_READY.md`          | Linux, Windows, Android | T1                 | Survey (Explorer 3)              |
| 5   | `linux_glibc_linkage`     | Configure Linux compilation linkage in `compile.sh` to prevent glibc TLS SIGFPE during dynamic driver loading | Linux x86_64            | M2                 | Survey (Explorer 2)              |
| 6   | `vmaf_builtin_models`     | Configure `libvmaf` with `-Dbuilt_in_models=true -Denable_float=true` in `build_libs.sh`                      | All                     | M2                 | User Feedback (yt-dlp benchmark) |
| 7   | `placebo_shaderc`         | Configure `libplacebo` with `libshaderc` support in `build_libs.sh`                                           | All                     | M2                 | User Feedback (yt-dlp benchmark) |
| 8   | `linux_ffmpeg_build`      | Compile `dist/linux-x86_64/ffmpeg` and `ffprobe` with all `--enable-*` flags                                  | Linux x86_64            | M2                 | AGENTS.md / ORIGINAL_REQUEST     |
| 9   | `linux_test_verification` | Run test suite on Linux achieving 100% pass across 77+ tests (including vmaf & placebo OK)                    | Linux x86_64            | M2                 | AGENTS.md / ORIGINAL_REQUEST     |
| 10  | `windows_ffmpeg_build`    | Cross-compile `dist/windows-x86_64/ffmpeg.exe` via MinGW                                                      | Windows x86_64          | M3                 | ORIGINAL_REQUEST                 |
| 11  | `windows_wine_validation` | Validate `ffmpeg.exe` under Wine achieving 100% test pass/graceful skip rate                                  | Windows x86_64          | M3                 | ORIGINAL_REQUEST                 |
| 12  | `android_arm64_build`     | Cross-compile `dist/android-arm64-v8a/ffmpeg` with MediaCodec                                                 | Android arm64-v8a       | M4                 | ORIGINAL_REQUEST                 |
| 13  | `android_arm32_build`     | Cross-compile `dist/android-armeabi-v7a/ffmpeg` with MediaCodec                                               | Android armeabi-v7a     | M4                 | ORIGINAL_REQUEST                 |
| 14  | `android_adb_validation`  | On-device validation runner with user confirmation guardrail before executing ADB                             | Android                 | M4                 | ORIGINAL_REQUEST / AGENTS.md     |
| 15  | `e2e_tier1_4_pass`        | 100% pass of all Tier 1-4 tests published in `TEST_READY.md` across platforms                                 | All                     | M5                 | Project Pattern                  |
| 16  | `e2e_tier5_adversarial`   | Tier 5 adversarial stress testing and coverage hardening                                                      | All                     | M5                 | Project Pattern                  |
| 17  | `reference_parity_audit`  | Capability & feature comparison verification against `yt-dlp/FFmpeg-Builds`                                   | Linux, Windows          | M5                 | ORIGINAL_REQUEST                 |

## Milestones

| #   | Name                                                   | Scope                                                                                                                                 | Dependencies   | Status      |
| --- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ----------- |
| T1  | E2E Testing Suite Track                                | 4-tier test runner, HW exception trapping, boundary & combination cases, `TEST_READY.md`                                              | none           | DONE        |
| M1  | Dependency Isolation & Docker Image Rebuild            | Fix environment leakage in `build_libs.sh`, validate patches with `view_files.sh`, rebuild Docker image                               | none           | IN_PROGRESS |
| M2  | Linux x86_64 Build & 100% Test Pass                    | Build libvmaf with built-in models & libplacebo with shaderc, compile Linux FFmpeg, verify 100% test pass                             | M1             | IN_PROGRESS |
| M3  | Windows x86_64 Cross-Compilation & Wine Validation     | Cross-compile `windows-x86_64` FFmpeg in Docker, verify `ffmpeg.exe` under Wine with 100% pass                                        | M1             | IN_PROGRESS |
| M4  | Android Builds & Device Validation Runner              | Compile `android-arm64-v8a` & `android-armeabi-v7a` in Docker, verify ELF binaries, setup ADB runner with user confirmation guardrail | M1             | IN_PROGRESS |
| M5  | Final Milestone: 100% E2E Pass & Adversarial Hardening | Validate 100% pass against `TEST_READY.md`, Tier 5 adversarial stress tests, victory report to Sentinel                               | T1, M2, M3, M4 | PLANNED     |

## Interface Contracts

### Docker Builder ↔ Compile Scripts

- Image Name: `vidra-ffmpeg-builder` (or service `ffmpeg-builder` in `docker-compose.yml`)
- Dependencies Output: `/compiled/<target_os>-<target_arch>/` containing `include/`, `lib/`, `lib/pkgconfig/`, `bin/`
- Toolchains:
  - Linux: Native GCC 13.3 + host pkg-config
  - Windows: `x86_64-w64-mingw32-gcc-posix` + `windows-pkg-config.sh` wrapper
  - Android: Android NDK r27d Clang LLVM (`aarch64-linux-android24-clang`, `armv7a-linux-androideabi24-clang`)

### FFmpeg Binaries ↔ Test Suite

- Entry Point (Linux): `dist/linux-x86_64/ffmpeg` (executable ELF, dynamically linked glibc, statically linked 3rd-party libs)
- Entry Point (Windows): `dist/windows-x86_64/ffmpeg.exe` (executable PE32+, executed via `wine`)
- Entry Point (Android): `dist/android-arm64-v8a/ffmpeg`, `dist/android-armeabi-v7a/ffmpeg` (executable ELF for Android Bionic)
- Test Command: `python3 test/test_ffmpeg.py <ffmpeg_binary_path> <output_temp_dir>`
- Test Pass Semantics: Return code 0 from test runner; software tests (including `libvmaf` and `libplacebo`) `STATUS: EXIT_SUCCESS`; unavailable GPU hardware tests (`vaapi`, `amf`, `libvpl`, `ffnvcodec` on CPU nodes) `STATUS: SKIPPED (Hardware not available)`.

## Code Layout

- `compile.sh`: Top-level and per-platform FFmpeg compilation script. (NEVER remove `--enable-*` flags).
- `Dockerfile` & `docker-compose.yml`: Containerized build environment.
- `docker-builder/`:
  - `build_libs.sh`: Third-party library build orchestration.
  - `patch_deps.sh`: Patch applicator script.
  - `patches/*.patch`: Platform and static compilation patches.
  - `download_deps.sh`, `extract_deps.sh`: Source tarball management.
- `test/`:
  - `test_ffmpeg.py`: Test suite and runner.
  - `view_files.sh`: Local source extraction and patch verification script.
- `dist/`:
  - `linux-x86_64/`: Linux static/standalone binaries (`ffmpeg`, `ffprobe`).
  - `windows-x86_64/`: Windows static binaries (`ffmpeg.exe`, `ffprobe.exe`).
  - `android-arm64-v8a/`: Android 64-bit ARM binaries.
  - `android-armeabi-v7a/`: Android 32-bit ARM binaries.
- `temp/`: Temporary build, test, and reference artifacts.
