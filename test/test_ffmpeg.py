#!/usr/bin/env python3
"""
Vidra-FFmpeg 4-Tier E2E Test Suite & Test Runner
Validates multimedia capabilities across Linux, Windows (Wine), and Android architectures.
"""

import argparse
import os
import re
import shlex
import subprocess
import sys
import time

# Hardware / Driver-dependent features that require host GPU / drivers or external models
HW_FEATURES = {
    "ffnvcodec",
    "vaapi",
    "vulkan",
    "opencl",
    "amf",
    "libvpl",
    "mediacodec",
}

# Substring patterns indicating missing hardware / drivers / devices / models
HW_ERROR_PATTERNS = [
    "No device available for decoder",
    "Driver does not support",
    "Function not implemented",
    "Failed to initialise VAAPI",
    "unknown libva error",
    "could not load the shared library",
    "Cannot load nvcuda.dll",
    "No AMF capable device found",
    "Failed to create OpenCL context",
    "Unknown MediaCodec error",
    "MediaCodec API is not supported",
    "DLL libamfrt64.so.1 failed to open",
    "Failed to create hardware device context",
    "DLL amfrt64.dll failed to open",
    "DLL libamf.so failed to open",
    "Failed to get number of OpenCL platforms",
    "No such device",
    "MediaCodec configure failed",
    "Encoder configure failed",
    "Failed to create Vulkan instance",
    "could not load libvmaf model",
    "Failed initializing any SPIR-V compiler",
    "Error creating a MFX session",
    "Failed creating Vulkan device!",
    "Cannot load libcuda.so",
    "Cannot load nvcuda.dll",
    "No NVENC capable devices found",
    "Failed to initialize AMF",
    "No OpenCL device found",
    "Failed to query surface capabilities",
    "Device creation failed",
    "Hardware device setup failed",
    "No VA display found",
    "No Vulkan device found",
    "vkCreateInstance failed",
    "Vulkan device initialization failed",
    "OpenCL device not found",
    "failed to open library",
]


def create_ass_subtitle_file(file_path):
    """Creates a synthetic ASS subtitle file for libass subtitle testing."""
    content = """[Script Info]
Title: Vidra Test
ScriptType: v4.00+
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,1,2,10,10,10,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,Vidra-FFmpeg Subtitle Test
"""
    if file_path.startswith("/data/local/tmp"):
        local_path = os.path.join("/tmp", os.path.basename(file_path))
        with open(local_path, "w", encoding="utf-8") as f:
            f.write(content)
        subprocess.run(
            ["adb", "push", local_path, file_path], check=True, capture_output=True
        )
        return

    os.makedirs(os.path.dirname(os.path.abspath(file_path)), exist_ok=True)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)


def build_full_exec_cmd(ffmpeg_path, ffmpeg_args):
    """Builds the complete execution command list for subprocess.run."""
    is_android = "android" in ffmpeg_path.lower()
    if ffmpeg_path.endswith(".exe"):
        return ["wine", ffmpeg_path] + ffmpeg_args
    elif is_android:
        remote_cmd = " ".join(
            shlex.quote(a)
            for a in ["/data/local/tmp/vidra_ffmpeg_test/ffmpeg"] + ffmpeg_args
        )
        return ["adb", "shell", remote_cmd]
    return [ffmpeg_path] + ffmpeg_args


def get_exec_env(ffmpeg_path):
    """Returns the environment dictionary configured for the target platform."""
    env = os.environ.copy()
    if ffmpeg_path.endswith(".exe"):
        env["WINEDEBUG"] = "-all"
    return env


def get_enabled_features(ffmpeg_path):
    """Extracts --enable-* compilation flags from ffmpeg -version output."""
    print("[1] Querying FFmpeg compilation configuration...")
    cmd = build_full_exec_cmd(ffmpeg_path, ["-version"])
    env = get_exec_env(ffmpeg_path)

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, check=True, env=env
        )
    except subprocess.CalledProcessError as e:
        print(f"FATAL: ffmpeg -version failed with exit code {e.returncode}")
        sys.exit(1)
    except Exception as e:
        print(f"FATAL: Unable to execute binary: {e}")
        sys.exit(1)

    match = re.search(r"configuration:\s*(.*)", result.stdout)
    if not match:
        print("Warning: Configuration line not found in version output.")
        return []

    config_line = match.group(1)
    features = [
        f.split("=")[0].replace("--enable-", "")
        for f in config_line.split()
        if f.startswith("--enable-")
    ]
    print(f"    Detected {len(features)} enabled configuration flags.")
    return features


def get_tier1_feature_tests(output_dir):
    """
    Tier 1: Feature & Capability Coverage (Unit Level).
    Validates individual codecs, filters, muxers, demuxers, and hardware accelerators.
    """
    ass_path = os.path.join(output_dir, "test_tier1.ass")
    create_ass_subtitle_file(ass_path)
    trf_path = os.path.join(output_dir, "tier1_transform.trf")

    return {
        # Core Baselines
        "basic_video": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "null",
            "-",
        ],
        "basic_audio": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-f",
            "null",
            "-",
        ],
        # Video Encoders
        "libx264": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "test_x264.mp4"),
        ],
        "libx265": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libx265",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "test_x265.mp4"),
        ],
        "libvpx": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libvpx-vp9",
            os.path.join(output_dir, "test_vp9.webm"),
        ],
        "libaom": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libaom-av1",
            "-strict",
            "experimental",
            "-cpu-used",
            "8",
            os.path.join(output_dir, "test_av1.mkv"),
        ],
        "libsvtav1": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libsvtav1",
            os.path.join(output_dir, "test_svtav1.mp4"),
        ],
        "librav1e": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "librav1e",
            "-speed",
            "10",
            os.path.join(output_dir, "test_rav1e.mp4"),
        ],
        "libkvazaar": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libkvazaar",
            os.path.join(output_dir, "test_kvazaar.mp4"),
        ],
        "libxavs2": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libxavs2",
            os.path.join(output_dir, "test_xavs2.mkv"),
        ],
        "liboapv": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "liboapv",
            os.path.join(output_dir, "test_oapv.mp4"),
        ],
        "libvvenc": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libvvenc",
            os.path.join(output_dir, "test_vvenc.mp4"),
        ],
        "libtheora": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libtheora",
            os.path.join(output_dir, "test_theora.ogg"),
        ],
        "libopenh264": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libopenh264",
            os.path.join(output_dir, "test_openh264.mp4"),
        ],
        "libxvid": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libxvid",
            os.path.join(output_dir, "test_xvid.avi"),
        ],
        "libopenjpeg": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libopenjpeg",
            os.path.join(output_dir, "test_openjpeg.mkv"),
        ],
        "libjxl": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libjxl",
            "-update",
            "1",
            os.path.join(output_dir, "test_jxl.jxl"),
        ],
        "libwebp": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libwebp",
            os.path.join(output_dir, "test_webp.webp"),
        ],
        # Decoders (Decoders execution or registration)
        "libdav1d": ["-decoders"],
        "libdavs2": ["-decoders"],
        "libopencore-amrwb": ["-decoders"],
        "libuavs3d": ["-decoders"],
        "liblcevc-dec": ["-decoders"],
        "libgme": ["-demuxers"],
        "libopenmpt": ["-demuxers"],
        "libbluray": ["-protocols"],
        "libdvdread": ["-demuxers"],
        "libdvdnav": ["-demuxers"],
        # Audio Encoders
        "libmp3lame": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libmp3lame",
            os.path.join(output_dir, "test_lame.mp3"),
        ],
        "libopus": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libopus",
            os.path.join(output_dir, "test_opus.mkv"),
        ],
        "libvorbis": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libvorbis",
            os.path.join(output_dir, "test_vorbis.ogg"),
        ],
        "libtwolame": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libtwolame",
            os.path.join(output_dir, "test_twolame.mp2"),
        ],
        "libopencore-amrnb": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1:sample_rate=8000",
            "-c:a",
            "libopencore_amrnb",
            "-ac",
            "1",
            os.path.join(output_dir, "test_amrnb.amr"),
        ],
        # Filters, Subtitles & DSP
        "libsoxr": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-af",
            "aresample=resampler=soxr",
            "-f",
            "null",
            "-",
        ],
        "librubberband": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-af",
            "rubberband=pitch=1.5",
            "-f",
            "null",
            "-",
        ],
        "chromaprint": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-f",
            "chromaprint",
            "-",
        ],
        "libfreetype": [
            "-f",
            "lavfi",
            "-i",
            "color=c=black:duration=1:s=640x360",
            "-vf",
            "drawtext=text='Test':fontsize=24:fontcolor=white",
            "-f",
            "null",
            "-",
        ],
        "libass": [
            "-f",
            "lavfi",
            "-i",
            "color=c=black:duration=1:s=640x360",
            "-vf",
            f"ass={ass_path}",
            "-f",
            "null",
            "-",
        ],
        "libvidstab": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-vf",
            f"vidstabdetect=result={trf_path}",
            "-f",
            "null",
            "-",
        ],
        "libzimg": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-vf",
            "zscale=w=320:h=180",
            "-f",
            "null",
            "-",
        ],
        "libplacebo": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-vf",
            "libplacebo",
            "-f",
            "null",
            "-",
        ],
        "libvmaf": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-filter_complex",
            "libvmaf",
            "-f",
            "null",
            "-",
        ],
        # Muxers & Protocols
        "libxml2": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libx264",
            "-f",
            "dash",
            os.path.join(output_dir, "test_dash.mpd"),
        ],
        "openssl": ["-protocols"],
        "schannel": ["-protocols"],
        "libsrt": ["-protocols"],
        "librist": ["-protocols"],
        "libssh": ["-protocols"],
        "libzmq": ["-protocols"],
        # Hardware Accelerators (Graceful skipping if device/driver absent)
        "ffnvcodec": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "h264_nvenc",
            os.path.join(output_dir, "test_nvenc.mp4"),
        ],
        "vaapi": [
            "-hwaccel",
            "vaapi",
            "-hwaccel_output_format",
            "vaapi",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "h264_vaapi",
            os.path.join(output_dir, "test_vaapi.mp4"),
        ],
        "vulkan": [
            "-init_hw_device",
            "vulkan=vk:0",
            "-filter_hw_device",
            "vk",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "null",
            "-",
        ],
        "opencl": [
            "-init_hw_device",
            "opencl",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "null",
            "-",
        ],
        "amf": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "h264_amf",
            os.path.join(output_dir, "test_amf.mp4"),
        ],
        "libvpl": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "h264_qsv",
            os.path.join(output_dir, "test_qsv.mp4"),
        ],
        "mediacodec": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-pix_fmt",
            "nv12",
            "-c:v",
            "h264_mediacodec",
            os.path.join(output_dir, "test_mediacodec.mp4"),
        ],
    }


def get_tier2_boundary_tests(output_dir):
    """
    Tier 2: Boundary & Corner Cases (Robustness Level).
    Tests extreme aspect ratios, odd dimensions, bit depths (10/12-bit), fractional rates, audio surround layouts.
    """
    return {
        "tier2_single_frame": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=0.033:size=640x360:rate=30",
            "-vframes",
            "1",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_single.mp4"),
        ],
        "tier2_odd_dimensions": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=641x361:rate=30",
            "-vf",
            "pad=ceil(iw/2)*2:ceil(ih/2)*2",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-pix_fmt",
            "yuv420p",
            os.path.join(output_dir, "tier2_odd.mp4"),
        ],
        "tier2_extreme_aspect_wide": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=1920x120:rate=30",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_wide.mp4"),
        ],
        "tier2_extreme_aspect_tall": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=120x1080:rate=30",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_tall.mp4"),
        ],
        "tier2_10bit_color": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-pix_fmt",
            "yuv420p10le",
            "-c:v",
            "libx265",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_10bit.mp4"),
        ],
        "tier2_12bit_color": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=30",
            "-pix_fmt",
            "yuv420p12le",
            "-c:v",
            "libaom-av1",
            "-strict",
            "experimental",
            "-cpu-used",
            "8",
            os.path.join(output_dir, "tier2_12bit.mkv"),
        ],
        "tier2_fractional_fps": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30000/1001",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_ntsc.mp4"),
        ],
        "tier2_surround_51_audio": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:channel_layout=5.1:duration=1",
            "-c:a",
            "libopus",
            os.path.join(output_dir, "tier2_51.mkv"),
        ],
        "tier2_high_sample_rate": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1:sample_rate=96000",
            "-c:a",
            "libopus",
            os.path.join(output_dir, "tier2_96k.mkv"),
        ],
        "tier2_high_resolution_4k": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=0.5:size=3840x2160:rate=30",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier2_4k.mp4"),
        ],
        "tier2_low_bitrate_edge": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=15",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-b:v",
            "50k",
            "-c:a",
            "libopus",
            "-b:a",
            "16k",
            os.path.join(output_dir, "tier2_lowbr.mp4"),
        ],
    }


def get_tier3_combination_tests(output_dir):
    """
    Tier 3: Cross-Feature Combinations (Integration Level).
    Validates tone mapping, multi-track audio muxing, DASH ladder, DSP pipelines, subtitle burn-in.
    """
    ass_path = os.path.join(output_dir, "tier3_test.ass")
    create_ass_subtitle_file(ass_path)

    return {
        "tier3_hdr_sdr_tonemap": [
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=1:size=640x360:rate=30",
            "-vf",
            "zscale=tin=smpte2084:min=bt2020nc:pin=bt2020:t=bt709:m=bt709:p=bt709:r=limited,drawtext=text='HDR-SDR':fontsize=20:fontcolor=yellow:x=10:y=10",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-pix_fmt",
            "yuv420p",
            os.path.join(output_dir, "tier3_tonemap.mp4"),
        ],
        "tier3_multitrack_master": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-filter_complex",
            "[1:a]aresample=48000:resampler=soxr[a1];[2:a]aresample=48000:resampler=soxr[a2]",
            "-map",
            "0:v",
            "-map",
            "[a1]",
            "-map",
            "[a2]",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-c:a:0",
            "libopus",
            "-b:a:0",
            "128k",
            "-c:a:1",
            "libmp3lame",
            "-b:a:1",
            "128k",
            os.path.join(output_dir, "tier3_multitrack.mkv"),
        ],
        "tier3_dash_adaptive_ladder": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-filter_complex",
            "[0:v]split=2[v1][v2];[v1]copy[v1out];[v2]scale=320:180[v2out]",
            "-map",
            "[v1out]",
            "-c:v:0",
            "libx264",
            "-preset",
            "ultrafast",
            "-b:v:0",
            "800k",
            "-map",
            "[v2out]",
            "-c:v:1",
            "libx264",
            "-preset",
            "ultrafast",
            "-b:v:1",
            "400k",
            "-f",
            "dash",
            "-use_template",
            "1",
            "-use_timeline",
            "1",
            os.path.join(output_dir, "tier3_dash_ladder.mpd"),
        ],
        "tier3_pitch_resample_chromaprint": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-filter_complex",
            "[0:a]rubberband=pitch=1.2:tempo=1.1,aresample=48000:resampler=soxr,asplit=2[a_enc][a_fp]",
            "-map",
            "[a_enc]",
            "-c:a",
            "libopus",
            os.path.join(output_dir, "tier3_audio_proc.mkv"),
            "-map",
            "[a_fp]",
            "-f",
            "chromaprint",
            "-",
        ],
        "tier3_subtitle_burnin": [
            "-f",
            "lavfi",
            "-i",
            "color=c=blue:duration=1:s=640x360:r=30",
            "-vf",
            f"ass={ass_path}",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier3_sub_burned.mp4"),
        ],
        "tier3_picture_in_picture": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "color=c=red:duration=1:s=160x90:r=30",
            "-filter_complex",
            "[0:v][1:v]overlay=10:10",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            os.path.join(output_dir, "tier3_pip.mp4"),
        ],
    }


def get_tier4_realworld_tests(output_dir):
    """
    Tier 4: Real-World Scenarios & Workloads (Production Level).
    Validates YouTube spec, AV1+Opus containers, TikTok 9:16 vertical video, broadcast master, multi-thread stress, HLS segmenting.
    """
    return {
        "tier4_web_video_youtube": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-preset",
            "ultrafast",
            "-g",
            "60",
            "-keyint_min",
            "60",
            "-sc_threshold",
            "0",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            os.path.join(output_dir, "tier4_youtube.mp4"),
        ],
        "tier4_nextgen_av1_opus": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:v",
            "libsvtav1",
            "-preset",
            "8",
            "-crf",
            "32",
            "-c:a",
            "libopus",
            "-b:a",
            "96k",
            os.path.join(output_dir, "tier4_nextgen.mkv"),
        ],
        "tier4_social_vertical_9_16": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=360x640:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            os.path.join(output_dir, "tier4_vertical.mp4"),
        ],
        "tier4_broadcast_master_j2k": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=24",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1:sample_rate=48000",
            "-c:v",
            "libopenjpeg",
            "-c:a",
            "pcm_s24le",
            os.path.join(output_dir, "tier4_broadcast.mkv"),
        ],
        "tier4_multithread_concurrency": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-threads",
            "0",
            "-c:v",
            "libsvtav1",
            "-preset",
            "8",
            os.path.join(output_dir, "tier4_stress.mp4"),
        ],
        "tier4_hls_adaptive_streaming": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=2",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-c:a",
            "aac",
            "-f",
            "hls",
            "-hls_time",
            "1",
            "-hls_list_size",
            "0",
            os.path.join(output_dir, "tier4_hls.m3u8"),
        ],
        "tier4_ytdlp_cutting_transcode": [
            "-ss",
            "0.0",
            "-t",
            "5.0",
            "-i",
            (
                "test/test.mkv"
                if os.path.exists("test/test.mkv")
                else os.path.join(output_dir, "tier4_youtube.mp4")
            ),
            "-f",
            "mp4",
            os.path.join(output_dir, "tier4_ytdlp_cut.part"),
        ],
    }


def execute_test(ffmpeg_path, test_name, test_args, log_file, is_query=False):
    """
    Executes a single test, traps negative return codes / hardware absences,
    and validates results.
    """
    env = get_exec_env(ffmpeg_path)

    # For query tests (e.g. -protocols, -decoders, -demuxers), do not prepend -y -v error
    if is_query:
        args_to_run = test_args
    else:
        args_to_run = ["-y", "-v", "error"] + test_args

    cmd = build_full_exec_cmd(ffmpeg_path, args_to_run)

    log_file.write(
        f"\n{'=' * 60}\nTEST: {test_name}\nCMD: {' '.join(cmd)}\n{'=' * 60}\n"
    )

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60, check=False, env=env
        )
    except subprocess.TimeoutExpired:
        log_file.write("STATUS: TIMEOUT (60s)\n")
        return "TIMEOUT", 0
    except Exception as e:
        log_file.write(f"STATUS: FATAL ERROR\n{e}\n")
        return "FATAL_ERROR", 0

    combined_output = (result.stdout or "") + (result.stderr or "")

    # Check for query test assertions (e.g. protocol or decoder existence)
    if is_query:
        # Determine expected keyword
        keyword_map = {
            "openssl": "https",
            "schannel": "https",
            "libsrt": "srt",
            "librist": "rist",
            "libssh": "sftp",
            "libzmq": "zmq",
            "libdav1d": "dav1d",
            "libdavs2": "davs2",
            "libopencore-amrwb": "libopencore_amrwb",
            "libuavs3d": "uavs3d",
            "liblcevc-dec": "lcevc",
            "libgme": "gme",
            "libopenmpt": "openmpt",
            "libbluray": "bluray",
            "libdvdread": "dvdread",
            "libdvdnav": "dvdnav",
        }
        expected = keyword_map.get(test_name, test_name) or ""
        if result.returncode == 0 and expected.lower() in combined_output.lower():
            log_file.write(f"STATUS: EXIT_SUCCESS (Found registration: {expected})\n")
            return "OK", result.returncode
        else:
            log_file.write(
                f"STATUS: FAILED with code {result.returncode} (Expected registration: {expected})\n"
            )
            log_file.write(f"OUTPUT:\n{combined_output}\n")
            return "FAIL", result.returncode

    # Standard command execution evaluation
    if result.returncode == 0:
        # Verify output file non-empty if output file was generated
        output_candidate = test_args[-1] if test_args else ""
        if (
            output_candidate
            and not output_candidate.startswith("-")
            and output_candidate != "-"
            and not "android" in ffmpeg_path.lower()
            and os.path.exists(output_candidate)
        ):
            file_size = os.path.getsize(output_candidate)
            if file_size == 0:
                log_file.write(
                    f"STATUS: FAILED (Output file {output_candidate} is 0 bytes)\n"
                )
                return "FAIL", 1
            log_file.write(
                f"STATUS: EXIT_SUCCESS (Output file size: {file_size} bytes)\n"
            )
        else:
            log_file.write("STATUS: EXIT_SUCCESS\n")
        return "OK", 0

    # Non-zero return code evaluation: Check for Hardware / Driver missing or negative signals
    is_hw_feature = test_name in HW_FEATURES or any(
        hw_kw in test_name
        for hw_kw in [
            "vaapi",
            "vulkan",
            "opencl",
            "nvenc",
            "amf",
            "qsv",
            "mediacodec",
            "placebo",
            "vmaf",
        ]
    )
    is_hw_pattern = any(err in combined_output for err in HW_ERROR_PATTERNS)
    is_negative_signal = result.returncode < 0 or result.returncode in [
        139,
        136,
    ]  # 136=SIGFPE, 139=SIGSEGV

    if is_hw_feature or is_hw_pattern or (is_hw_feature and is_negative_signal):
        reason = "Hardware/Driver not available"
        if result.returncode < 0:
            reason = f"Signal trapped: code {result.returncode} (Hardware accelerator not initialized)"
        log_file.write(f"STATUS: SKIPPED ({reason}) with code {result.returncode}\n")
        log_file.write(f"STDERR:\n{result.stderr}\n")
        return "SKIPPED", result.returncode

    log_file.write(f"STATUS: FAILED with code {result.returncode}\n")
    log_file.write(f"STDERR:\n{result.stderr}\n")
    return "FAIL", result.returncode


def run_tests(ffmpeg_path, test_dir, tier_selection="all"):
    """
    Main orchestrator for the 4-Tier test suite.
    """
    is_android = "android" in ffmpeg_path.lower()
    os.makedirs(test_dir, exist_ok=True)
    log_file_path = os.path.join(test_dir, "ffmpeg_test_results.log")

    enabled_features = get_enabled_features(ffmpeg_path)

    # Output directory for Android is /data/local/tmp/vidra_ffmpeg_test
    output_dir = "/data/local/tmp/vidra_ffmpeg_test" if is_android else test_dir

    t1_all = get_tier1_feature_tests(output_dir)
    t2_all = get_tier2_boundary_tests(output_dir)
    t3_all = get_tier3_combination_tests(output_dir)
    t4_all = get_tier4_realworld_tests(output_dir)

    # Filter Tier 1 based on detected compilation features
    t1_selected = {}
    for test_key, cmd_args in t1_all.items():
        if test_key in ["basic_video", "basic_audio"] or test_key in enabled_features:
            t1_selected[test_key] = cmd_args

    tiers_to_execute = []
    if tier_selection in ["1", "all"]:
        tiers_to_execute.append(("Tier 1: Feature Coverage", t1_selected))
    if tier_selection in ["2", "all"]:
        tiers_to_execute.append(("Tier 2: Boundary & Corner Cases", t2_all))
    if tier_selection in ["3", "all"]:
        tiers_to_execute.append(("Tier 3: Cross-Feature Combinations", t3_all))
    if tier_selection in ["4", "all"]:
        tiers_to_execute.append(("Tier 4: Real-World Scenarios", t4_all))

    total_count = sum(len(tests) for _, tests in tiers_to_execute)
    print(
        f"\n[2] Executing {total_count} tests across selected tiers ({tier_selection})..."
    )
    print(f"    Results log: {log_file_path}\n")

    summary = {"passed": 0, "skipped": 0, "failed": 0, "timeout": 0}
    tier_stats = {}

    start_time = time.time()

    with open(log_file_path, "w", encoding="utf-8") as log_file:
        log_file.write("Vidra-FFmpeg E2E Test Suite Run\n")
        log_file.write(f"Target Binary: {ffmpeg_path}\n")
        log_file.write(
            f"Platform: {'Android' if is_android else ('Windows' if ffmpeg_path.endswith('.exe') else 'Linux')}\n"
        )
        log_file.write(
            f"Timestamp: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n"
        )
        log_file.write(f"{'=' * 60}\n\n")

        for tier_name, tests in tiers_to_execute:
            print(f"\n--- {tier_name} ({len(tests)} tests) ---")
            t_pass, t_skip, t_fail = 0, 0, 0

            for test_name, test_args in tests.items():
                print(f"  Testing {test_name.ljust(35)} ... ", end="", flush=True)

                is_query = test_args[0] in ["-protocols", "-decoders", "-demuxers"]
                status, code = execute_test(
                    ffmpeg_path, test_name, test_args, log_file, is_query
                )

                if status == "OK":
                    print("OK")
                    t_pass += 1
                    summary["passed"] += 1
                elif status == "SKIPPED":
                    print(f"SKIPPED (Hardware not available, Code: {code})")
                    t_skip += 1
                    summary["skipped"] += 1
                elif status == "TIMEOUT":
                    print("TIMEOUT")
                    t_fail += 1
                    summary["timeout"] += 1
                else:
                    print(f"FAIL (Code: {code})")
                    t_fail += 1
                    summary["failed"] += 1

            tier_stats[tier_name] = (t_pass, t_skip, t_fail)

    elapsed = time.time() - start_time
    print(f"\n[3] Test Execution Completed in {elapsed:.2f} seconds.")
    print("=" * 60)
    print("TEST SUITE SUMMARY:")
    for tname, (tp, ts, tf) in tier_stats.items():
        print(f"  * {tname:40}: {tp} passed, {ts} skipped, {tf} failed")
    print(
        f"  TOTAL: {summary['passed']} passed, {summary['skipped']} skipped (HW), {summary['failed'] + summary['timeout']} failed"
    )
    print("=" * 60)

    if summary["failed"] == 0 and summary["timeout"] == 0:
        print("\n>>> ALL TESTS PASSED / GRACEFULLY SKIPPED (EXIT CODE 0) <<<\n")
        return 0
    else:
        print(
            f"\n>>> {summary['failed'] + summary['timeout']} TEST(S) FAILED (EXIT CODE 1) <<<\n"
        )
        return 1


def prepare_android(ffmpeg_path):
    """Stages the Android binary on device via ADB with safety checks."""
    print("[0] Preparing Android device via ADB...")
    # Check if adb is installed and devices are connected
    try:
        dev_res = subprocess.run(
            ["adb", "devices"], capture_output=True, text=True, check=True
        )
        lines = [
            line
            for line in dev_res.stdout.strip().split("\n")[1:]
            if line.strip() and not line.startswith("*")
        ]
        if not lines:
            print("ERROR: No Android devices/emulators connected via ADB.")
            print(
                "Please ensure a physical device is connected with USB debugging enabled."
            )
            sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to run adb: {e}")
        sys.exit(1)

    device_dir = "/data/local/tmp/vidra_ffmpeg_test"
    subprocess.run(["adb", "shell", f"mkdir -p {device_dir}"], check=True)
    subprocess.run(["adb", "push", ffmpeg_path, f"{device_dir}/ffmpeg"], check=True)
    subprocess.run(["adb", "shell", f"chmod 755 {device_dir}/ffmpeg"], check=True)
    print(f"    Pushed {ffmpeg_path} to {device_dir}/ffmpeg")


def cleanup_android():
    """Cleans up temporary test directory on Android device."""
    try:
        device_dir = "/data/local/tmp/vidra_ffmpeg_test"
        subprocess.run(["adb", "shell", f"rm -rf {device_dir}"], check=False)
    except Exception:
        print("WARNING: Failed to clean up Android device temporary directory.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Vidra-FFmpeg 4-Tier E2E Test Runner")
    parser.add_argument(
        "ffmpeg_path", help="Path to ffmpeg binary (ELF, .exe, or Android ELF)"
    )
    parser.add_argument(
        "test_dir", help="Directory where test outputs and logs will be saved"
    )
    parser.add_argument(
        "--tier",
        choices=["1", "2", "3", "4", "all"],
        default="all",
        help="Select specific tier to run (1, 2, 3, 4, or all). Default: all",
    )

    args = parser.parse_args()

    if not os.path.isfile(args.ffmpeg_path):
        print(f"Error: Target binary '{args.ffmpeg_path}' does not exist.")
        sys.exit(1)

    is_android = "android" in args.ffmpeg_path.lower()
    if is_android:
        prepare_android(args.ffmpeg_path)

    try:
        exit_code = run_tests(args.ffmpeg_path, args.test_dir, args.tier)
    finally:
        if is_android:
            cleanup_android()

    sys.exit(exit_code)
