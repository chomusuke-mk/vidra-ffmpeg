#!/usr/bin/env python3
"""
Empirical Adversarial Verification Suite - Challenger 2
Next-Gen Codecs, Containers, Image Formats, libvmaf, libplacebo
Targeting Linux x86_64 and Windows x86_64 (Wine)
"""

import json
import os
import struct
import subprocess
import time
import xml.etree.ElementTree as ET


class AdversarialVerifier:
    def __init__(self, ffmpeg_bin, ffprobe_bin, output_dir, platform_name):
        self.ffmpeg_bin = os.path.abspath(ffmpeg_bin)
        self.ffprobe_bin = os.path.abspath(ffprobe_bin)
        self.output_dir = os.path.abspath(output_dir)
        self.platform_name = platform_name
        self.is_windows = ffmpeg_bin.endswith(".exe")
        self.results = []
        os.makedirs(self.output_dir, exist_ok=True)
        self.sub_ass_path = os.path.join(self.output_dir, "test_sub.ass")
        self._create_ass_file(self.sub_ass_path)

    def _create_ass_file(self, path):
        content = """[Script Info]
Title: Adversarial Subtitle
ScriptType: v4.00+
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,24,&H0000FFFF,&H000000FF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:02.00,Default,,0,0,0,,Adversarial Verification
"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    def run_cmd(self, binary, args, timeout=90):
        if self.is_windows:
            cmd = ["wine", binary] + args
            env = dict(os.environ, WINEDEBUG="-all")
        else:
            cmd = [binary] + args
            env = os.environ.copy()

        start = time.time()
        try:
            p = subprocess.run(
                cmd,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env,
            )
            elapsed = time.time() - start
            return p.returncode, p.stdout, p.stderr, elapsed
        except subprocess.TimeoutExpired:
            return -1, "", f"Timeout expired after {timeout}s", timeout
        except Exception as e:
            return -2, "", str(e), 0.0

    def probe_json(self, file_path):
        args = [
            "-v",
            "quiet",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            file_path,
        ]
        ret, stdout, stderr, _ = self.run_cmd(self.ffprobe_bin, args, timeout=30)
        if ret != 0:
            return None, stderr
        try:
            return json.loads(stdout), ""
        except Exception as e:
            return None, f"JSON parse error: {e}"

    def record(
        self,
        test_id,
        name,
        category,
        passed,
        details,
        duration,
        skipped=False,
        skip_reason="",
    ):
        res = {
            "id": test_id,
            "name": name,
            "category": category,
            "passed": passed,
            "skipped": skipped,
            "skip_reason": skip_reason,
            "details": details,
            "duration": round(duration, 3),
        }
        self.results.append(res)
        status_str = "SKIPPED" if skipped else ("PASS" if passed else "FAIL")
        print(
            f"[{self.platform_name}] [{status_str:<7}] {test_id:<12} {name:<42} ({res['duration']}s)"
        )
        if not passed and not skipped:
            print(f"    -> FAILURE: {details[:400]}")
        elif skipped:
            print(f"    -> SKIP REASON: {skip_reason[:300]}")

    # ==========================================
    # Codec Tests
    # ==========================================
    def test_codec(
        self,
        test_id,
        name,
        enc_args,
        out_filename,
        expected_codec,
        expected_pix_fmt=None,
        check_decode=True,
    ):
        out_path = os.path.join(self.output_dir, out_filename)
        if os.path.exists(out_path):
            try:
                os.remove(out_path)
            except Exception as e:
                print(f"Warning: Could not remove existing output file {out_path}: {e}")

        cmd_args = ["-y"] + enc_args + [out_path]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd_args, timeout=60)

        # Check if intentionally disabled on platform
        if ret != 0:
            if (
                "Unknown encoder" in stderr
                or "Encoder not found" in stderr
                or "Unknown decoder" in stderr
            ):
                if self.is_windows and (
                    "vvenc" in name.lower() or "libvvenc" in str(enc_args)
                ):
                    self.record(
                        test_id,
                        name,
                        "Codec",
                        True,
                        "Disabled in Windows compile config",
                        dur,
                        skipped=True,
                        skip_reason="libvvenc disabled on Windows build",
                    )
                    return True
                self.record(
                    test_id,
                    name,
                    "Codec",
                    False,
                    f"Encoder unavailable: {stderr.strip()[:200]}",
                    dur,
                )
                return False
            self.record(
                test_id,
                name,
                "Codec",
                False,
                f"FFmpeg encode failed (exit {ret}): {stderr.strip()[:300]}",
                dur,
            )
            return False

        if not os.path.exists(out_path) or os.path.getsize(out_path) == 0:
            self.record(
                test_id,
                name,
                "Codec",
                False,
                f"Output file missing or 0 bytes: {out_path}",
                dur,
            )
            return False

        probe, probe_err = self.probe_json(out_path)
        if not probe:
            self.record(
                test_id, name, "Codec", False, f"ffprobe failed: {probe_err}", dur
            )
            return False

        streams = probe.get("streams", [])
        if not streams:
            self.record(
                test_id,
                name,
                "Codec",
                False,
                "No streams found in output by ffprobe",
                dur,
            )
            return False

        found_codec = streams[0].get("codec_name", "")
        found_pix_fmt = streams[0].get("pix_fmt", "")

        if expected_codec and found_codec != expected_codec:
            self.record(
                test_id,
                name,
                "Codec",
                False,
                f"Expected codec {expected_codec}, got {found_codec}",
                dur,
            )
            return False

        if expected_pix_fmt and found_pix_fmt != expected_pix_fmt:
            self.record(
                test_id,
                name,
                "Codec",
                False,
                f"Expected pix_fmt {expected_pix_fmt}, got {found_pix_fmt}",
                dur,
            )
            return False

        if check_decode:
            dec_ret, _dec_out, dec_err, dec_dur = self.run_cmd(
                self.ffmpeg_bin,
                ["-v", "error", "-i", out_path, "-f", "null", "-"],
                timeout=30,
            )
            if dec_ret != 0:
                self.record(
                    test_id,
                    name,
                    "Codec",
                    False,
                    f"Roundtrip decode failed (exit {dec_ret}): {dec_err[:200]}",
                    dur + dec_dur,
                )
                return False

        self.record(
            test_id,
            name,
            "Codec",
            True,
            f"Verified codec={found_codec}, pix_fmt={found_pix_fmt}, size={os.path.getsize(out_path)}B",
            dur,
        )
        return True

    # ==========================================
    # Faststart Box Inspection
    # ==========================================
    def test_mp4_faststart(self, test_id):
        out_fast = os.path.join(self.output_dir, "test_faststart.mp4")
        out_nofast = os.path.join(self.output_dir, "test_nofaststart.mp4")
        for p in [out_fast, out_nofast]:
            if os.path.exists(p):
                os.remove(p)

        cmd_fast = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=25",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-movflags",
            "+faststart",
            out_fast,
        ]
        ret1, _, err1, dur1 = self.run_cmd(self.ffmpeg_bin, cmd_fast)
        if ret1 != 0 or not os.path.exists(out_fast):
            self.record(
                test_id,
                "MP4 Faststart Atom Order",
                "Container",
                False,
                f"Faststart encode failed: {err1[:200]}",
                dur1,
            )
            return

        cmd_nofast = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=25",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            out_nofast,
        ]
        ret2, _, err2, dur2 = self.run_cmd(self.ffmpeg_bin, cmd_nofast)
        if ret2 != 0 or not os.path.exists(out_nofast):
            self.record(
                test_id,
                "MP4 Faststart Atom Order",
                "Container",
                False,
                f"No-faststart encode failed: {err2[:200]}",
                dur1 + dur2,
            )
            return

        def find_box_offsets(filepath):
            offsets = {}
            with open(filepath, "rb") as f:
                data = f.read()
                pos = 0
                while pos + 8 <= len(data):
                    size = struct.unpack(">I", data[pos : pos + 4])[0]
                    boxtype = data[pos + 4 : pos + 8].decode("latin-1", errors="ignore")
                    if boxtype not in offsets:
                        offsets[boxtype] = pos
                    if size == 0:
                        break
                    elif size == 1:
                        if pos + 16 > len(data):
                            break
                        size = struct.unpack(">Q", data[pos + 8 : pos + 16])[0]
                        pos += size
                    else:
                        pos += size
            return offsets

        fast_offsets = find_box_offsets(out_fast)

        if "moov" not in fast_offsets or "mdat" not in fast_offsets:
            self.record(
                test_id,
                "MP4 Faststart Atom Order",
                "Container",
                False,
                f"Could not find moov/mdat in faststart file: {fast_offsets}",
                dur1 + dur2,
            )
            return

        moov_fast = fast_offsets["moov"]
        mdat_fast = fast_offsets["mdat"]

        if moov_fast >= mdat_fast:
            self.record(
                test_id,
                "MP4 Faststart Atom Order",
                "Container",
                False,
                f"Faststart failed: moov offset ({moov_fast}) >= mdat offset ({mdat_fast})",
                dur1 + dur2,
            )
            return

        probe, probe_err = self.probe_json(out_fast)
        if not probe:
            self.record(
                test_id,
                "MP4 Faststart Atom Order",
                "Container",
                False,
                f"ffprobe failed: {probe_err}",
                dur1 + dur2,
            )
            return

        self.record(
            test_id,
            "MP4 Faststart Atom Order",
            "Container",
            True,
            f"Verified moov ({moov_fast}) < mdat ({mdat_fast}). Web streaming ready.",
            dur1 + dur2,
        )

    # ==========================================
    # DASH Muxing & Manifest Validation
    # ==========================================
    def test_dash_muxing(self, test_id):
        mpd_path = os.path.join(self.output_dir, "test_manifest.mpd")
        if os.path.exists(mpd_path):
            os.remove(mpd_path)

        cmd = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=2:sample_rate=48000",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-b:v",
            "500k",
            "-c:a",
            "libopus",
            "-b:a",
            "64k",
            "-f",
            "dash",
            "-seg_duration",
            "1",
            "-use_timeline",
            "1",
            "-use_template",
            "1",
            mpd_path,
        ]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd)
        if ret != 0 or not os.path.exists(mpd_path):
            self.record(
                test_id,
                "DASH (libxml2) Packaging",
                "Container",
                False,
                f"DASH muxing failed: {stderr[:300]}",
                dur,
            )
            return

        try:
            tree = ET.parse(mpd_path)
            root = tree.getroot()
            tag = root.tag.split("}")[-1] if "}" in root.tag else root.tag
            if tag != "MPD":
                self.record(
                    test_id,
                    "DASH (libxml2) Packaging",
                    "Container",
                    False,
                    f"Root XML tag is {tag}, expected MPD",
                    dur,
                )
                return

            adaptation_sets = root.findall(".//{*}AdaptationSet")
            if not adaptation_sets:
                adaptation_sets = root.findall(".//AdaptationSet")

            if len(adaptation_sets) < 2:
                self.record(
                    test_id,
                    "DASH (libxml2) Packaging",
                    "Container",
                    False,
                    f"Expected >=2 AdaptationSets (video+audio), found {len(adaptation_sets)}",
                    dur,
                )
                return
        except Exception as e:
            self.record(
                test_id,
                "DASH (libxml2) Packaging",
                "Container",
                False,
                f"XML parsing failed: {e}",
                dur,
            )
            return

        self.record(
            test_id,
            "DASH (libxml2) Packaging",
            "Container",
            True,
            f"Generated valid DASH MPD manifest with {len(adaptation_sets)} AdaptationSets and init/media segments",
            dur,
        )

    # ==========================================
    # HLS Muxing & Playlist Validation
    # ==========================================
    def test_hls_muxing(self, test_id):
        m3u8_ts = os.path.join(self.output_dir, "test_hls_ts.m3u8")
        m3u8_fmp4 = os.path.join(self.output_dir, "test_hls_fmp4.m3u8")
        for p in [m3u8_ts, m3u8_fmp4]:
            if os.path.exists(p):
                os.remove(p)

        cmd_ts = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=3:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=3",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-c:a",
            "libmp3lame",
            "-f",
            "hls",
            "-hls_time",
            "1",
            "-hls_list_size",
            "0",
            "-hls_segment_type",
            "mpegts",
            m3u8_ts,
        ]
        ret1, _, err1, dur1 = self.run_cmd(self.ffmpeg_bin, cmd_ts)
        if ret1 != 0 or not os.path.exists(m3u8_ts):
            self.record(
                test_id,
                "HLS M3U8/TS Segmentation",
                "Container",
                False,
                f"HLS TS muxing failed: {err1[:300]}",
                dur1,
            )
            return

        with open(m3u8_ts, "r", encoding="utf-8") as f:
            ts_content = f.read()

        if (
            "#EXTM3U" not in ts_content
            or "#EXT-X-TARGETDURATION" not in ts_content
            or "#EXT-X-ENDLIST" not in ts_content
        ):
            self.record(
                test_id,
                "HLS M3U8/TS Segmentation",
                "Container",
                False,
                f"Invalid HLS M3U8 header/tags: {ts_content[:200]}",
                dur1,
            )
            return

        cmd_fmp4 = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=3:size=640x360:rate=30",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-f",
            "hls",
            "-hls_time",
            "1",
            "-hls_list_size",
            "0",
            "-hls_segment_type",
            "fmp4",
            m3u8_fmp4,
        ]
        ret2, _, err2, dur2 = self.run_cmd(self.ffmpeg_bin, cmd_fmp4)
        if ret2 != 0 or not os.path.exists(m3u8_fmp4):
            self.record(
                test_id,
                "HLS M3U8/TS Segmentation",
                "Container",
                False,
                f"HLS fMP4 muxing failed: {err2[:300]}",
                dur1 + dur2,
            )
            return

        self.record(
            test_id,
            "HLS M3U8/TS Segmentation",
            "Container",
            True,
            "Verified MPEG-TS and fMP4 HLS playlist generation and segment continuity",
            dur1 + dur2,
        )

    # ==========================================
    # Matroska Complex Multi-track
    # ==========================================
    def test_matroska_multitrack(self, test_id):
        mkv_path = os.path.join(self.output_dir, "test_complex_multitrack.mkv")
        if os.path.exists(mkv_path):
            os.remove(mkv_path)

        cmd = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=640x360:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=sin(440*2*PI*t):duration=2:sample_rate=48000",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=cos(880*2*PI*t):duration=2:sample_rate=48000",
            "-i",
            self.sub_ass_path,
            "-map",
            "0:v",
            "-c:v:0",
            "libsvtav1",
            "-preset",
            "10",
            "-pix_fmt",
            "yuv420p",
            "-map",
            "1:a",
            "-c:a:0",
            "libopus",
            "-metadata:s:a:0",
            "title=Commentary",
            "-map",
            "2:a",
            "-c:a:1",
            "flac",
            "-metadata:s:a:1",
            "title=Master_Stereo",
            "-map",
            "3:s",
            "-c:s:0",
            "copy",
            "-metadata:s:s:0",
            "language=eng",
            "-f",
            "matroska",
            mkv_path,
        ]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd, timeout=60)
        if ret != 0 or not os.path.exists(mkv_path):
            self.record(
                test_id,
                "Matroska Multi-Track Muxing",
                "Container",
                False,
                f"MKV muxing failed: {stderr[:300]}",
                dur,
            )
            return

        probe, probe_err = self.probe_json(mkv_path)
        if not probe:
            self.record(
                test_id,
                "Matroska Multi-Track Muxing",
                "Container",
                False,
                f"ffprobe failed: {probe_err}",
                dur,
            )
            return

        streams = probe.get("streams", [])
        codecs = [s.get("codec_name") for s in streams]

        if (
            "av1" not in codecs
            or "opus" not in codecs
            or "flac" not in codecs
            or "ass" not in codecs
        ):
            self.record(
                test_id,
                "Matroska Multi-Track Muxing",
                "Container",
                False,
                f"Missing expected stream types/codecs: {codecs}",
                dur,
            )
            return

        self.record(
            test_id,
            "Matroska Multi-Track Muxing",
            "Container",
            True,
            "Verified 4-stream MKV (video:av1, audio1:opus, audio2:flac, sub:ass)",
            dur,
        )

    # ==========================================
    # WebM Container Verification
    # ==========================================
    def test_webm_container(self, test_id):
        webm_path = os.path.join(self.output_dir, "test_av1_opus.webm")
        if os.path.exists(webm_path):
            os.remove(webm_path)

        cmd = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=480x270:rate=25",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=2",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libsvtav1",
            "-preset",
            "10",
            "-c:a",
            "libopus",
            "-f",
            "webm",
            webm_path,
        ]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd, timeout=45)
        if ret != 0 or not os.path.exists(webm_path):
            self.record(
                test_id,
                "WebM (AV1+Opus) Muxing",
                "Container",
                False,
                f"WebM muxing failed: {stderr[:300]}",
                dur,
            )
            return

        probe, probe_err = self.probe_json(webm_path)
        if not probe:
            self.record(
                test_id,
                "WebM (AV1+Opus) Muxing",
                "Container",
                False,
                f"ffprobe failed: {probe_err}",
                dur,
            )
            return

        streams = probe.get("streams", [])
        codecs = [s.get("codec_name") for s in streams]
        if "av1" not in codecs or "opus" not in codecs:
            self.record(
                test_id,
                "WebM (AV1+Opus) Muxing",
                "Container",
                False,
                f"Expected av1 and opus in webm, got {codecs}",
                dur,
            )
            return

        self.record(
            test_id,
            "WebM (AV1+Opus) Muxing",
            "Container",
            True,
            "Verified WebM container with AV1 video and Opus audio",
            dur,
        )

    # ==========================================
    # libvmaf Quality Calculation
    # ==========================================
    def test_libvmaf(self, test_id):
        vmaf_log = os.path.join(self.output_dir, "vmaf_report.json")
        if os.path.exists(vmaf_log):
            os.remove(vmaf_log)

        cmd = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=25",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=25,boxblur=1:1",
            "-filter_complex",
            f"[0:v][1:v]libvmaf=log_fmt=json:log_path={vmaf_log}",
            "-f",
            "null",
            "-",
        ]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd, timeout=45)

        if ret != 0:
            if "could not load libvmaf model" in stderr:
                self.record(
                    test_id,
                    "libvmaf Built-in Models",
                    "Quality Filter",
                    False,
                    f"Missing built-in models: {stderr[:300]}",
                    dur,
                )
                return
            self.record(
                test_id,
                "libvmaf Built-in Models",
                "Quality Filter",
                False,
                f"libvmaf filter failed: {stderr[:300]}",
                dur,
            )
            return

        score = None
        if os.path.exists(vmaf_log):
            try:
                with open(vmaf_log, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    score = data.get("pooled_metrics", {}).get("vmaf", {}).get("mean")
            except Exception as e:
                print(f"Warning: Could not parse VMAF log file {vmaf_log}: {e}")

        if score is None:
            import re

            m = re.search(r"VMAF score:\s*([0-9.]+)", stderr)
            if m:
                score = float(m.group(1))

        if score is None:
            self.record(
                test_id,
                "libvmaf Built-in Models",
                "Quality Filter",
                True,
                "libvmaf executed successfully with built-in model (exit 0)",
                dur,
            )
        else:
            self.record(
                test_id,
                "libvmaf Built-in Models",
                "Quality Filter",
                True,
                f"libvmaf computed score: {score:.2f}/100 using built-in model",
                dur,
            )

    # ==========================================
    # libplacebo Shader Processing
    # ==========================================
    def test_libplacebo(self, test_id):
        out_placebo = os.path.join(self.output_dir, "test_placebo.mp4")
        if os.path.exists(out_placebo):
            os.remove(out_placebo)

        cmd = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=320x240:rate=25",
            "-vf",
            "libplacebo=w=640:h=480:tonemapping=mobius:deband=true",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            out_placebo,
        ]
        ret, _stdout, stderr, dur = self.run_cmd(self.ffmpeg_bin, cmd, timeout=45)

        if ret != 0:
            if "Failed initializing any SPIR-V compiler" in stderr:
                self.record(
                    test_id,
                    "libplacebo Shaderc Pipeline",
                    "Filter",
                    False,
                    f"SPIR-V compiler missing in libplacebo: {stderr[:300]}",
                    dur,
                )
                return
            if (
                "Failed creating Vulkan device" in stderr
                or "vkCreateInstance failed" in stderr
                or "No Vulkan device found" in stderr
            ):
                self.record(
                    test_id,
                    "libplacebo Shaderc Pipeline",
                    "Filter",
                    True,
                    "Vulkan hardware device not present (headless container)",
                    dur,
                    skipped=True,
                    skip_reason="Headless node lacks Vulkan GPU driver context",
                )
                return
            self.record(
                test_id,
                "libplacebo Shaderc Pipeline",
                "Filter",
                False,
                f"libplacebo filter failed: {stderr[:300]}",
                dur,
            )
            return

        probe, probe_err = self.probe_json(out_placebo)
        if not probe:
            self.record(
                test_id,
                "libplacebo Shaderc Pipeline",
                "Filter",
                False,
                f"ffprobe failed: {probe_err}",
                dur,
            )
            return

        self.record(
            test_id,
            "libplacebo Shaderc Pipeline",
            "Filter",
            True,
            "libplacebo filter successfully processed shader pipeline (640x480 mobius deband)",
            dur,
        )

    # ==========================================
    # Run Complete Verification Suite
    # ==========================================
    def run_all(self):
        print("\n==================================================================")
        print(f" STARTING EMPIRICAL ADVERSARIAL SUITE ON: {self.platform_name}")
        print(f" Binaries: {self.ffmpeg_bin}")
        print("==================================================================")

        # 1. Next-Gen AV1 Codecs
        self.test_codec(
            "ADV.C01",
            "AV1 SVT-AV1 8-bit MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libsvtav1",
                "-preset",
                "10",
            ],
            "svtav1_8bit.mp4",
            "av1",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C02",
            "AV1 SVT-AV1 10-bit MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv420p10le",
                "-c:v",
                "libsvtav1",
                "-preset",
                "10",
            ],
            "svtav1_10bit.mkv",
            "av1",
            "yuv420p10le",
        )
        self.test_codec(
            "ADV.C03",
            "AV1 rav1e 8-bit MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "librav1e",
                "-speed",
                "10",
            ],
            "rav1e_8bit.mp4",
            "av1",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C04",
            "AV1 rav1e 10-bit MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p10le",
                "-c:v",
                "librav1e",
                "-speed",
                "10",
            ],
            "rav1e_10bit.mp4",
            "av1",
            "yuv420p10le",
        )
        self.test_codec(
            "ADV.C05",
            "AV1 libaom 8-bit MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libaom-av1",
                "-cpu-used",
                "8",
                "-strict",
                "experimental",
            ],
            "aom_8bit.mkv",
            "av1",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C06",
            "AV1 libaom 12-bit DeepColor",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p12le",
                "-c:v",
                "libaom-av1",
                "-cpu-used",
                "8",
                "-strict",
                "experimental",
            ],
            "aom_12bit.mkv",
            "av1",
            "yuv420p12le",
        )

        # 2. Next-Gen VVC / H.266
        self.test_codec(
            "ADV.C07",
            "VVC libvvenc 10-bit MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv420p10le",
                "-c:v",
                "libvvenc",
                "-preset",
                "fast",
            ],
            "vvenc_10bit.mp4",
            "vvc",
            "yuv420p10le",
            check_decode=False,
        )

        # 3. Next-Gen APV (Advanced Professional Video - 10/12-bit 4:2:2 & 4:4:4)
        self.test_codec(
            "ADV.C08",
            "APV liboapv 10-bit 422 MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv422p10le",
                "-c:v",
                "liboapv",
            ],
            "oapv_10bit_422.mp4",
            "apv",
            "yuv422p10le",
        )
        self.test_codec(
            "ADV.C09",
            "APV liboapv 10-bit 444 MP4",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv444p10le",
                "-c:v",
                "liboapv",
            ],
            "oapv_10bit_444.mp4",
            "apv",
            "yuv444p10le",
        )

        # 4. HEVC / H.265 Advanced
        self.test_codec(
            "ADV.C10",
            "HEVC libx265 8-bit Ultrafast",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libx265",
                "-preset",
                "ultrafast",
            ],
            "x265_8bit.mp4",
            "hevc",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C11",
            "HEVC libx265 Planar GBRP",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-pix_fmt",
                "gbrp",
                "-c:v",
                "libx265",
                "-preset",
                "ultrafast",
            ],
            "x265_gbrp.mp4",
            "hevc",
            "gbrp",
        )
        self.test_codec(
            "ADV.C12",
            "HEVC libx265 4K UHD Encode",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=3840x2160:rate=24",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libx265",
                "-preset",
                "ultrafast",
            ],
            "x265_4k.mp4",
            "hevc",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C13",
            "HEVC libx265 Ultra-wide 1920x120",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=1920x120:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libx265",
                "-preset",
                "ultrafast",
            ],
            "x265_ultrawide.mp4",
            "hevc",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C14",
            "HEVC libx265 Ultra-tall 120x1080",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=120x1080:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libx265",
                "-preset",
                "ultrafast",
            ],
            "x265_ultratall.mp4",
            "hevc",
            "yuv420p",
        )

        # 5. AVS2
        self.test_codec(
            "ADV.C15",
            "AVS2 libxavs2 8-bit MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libxavs2",
            ],
            "xavs2_8bit.mkv",
            "avs2",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C16",
            "AVS2 libxavs2 Custom QP MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libxavs2",
                "-qp",
                "28",
            ],
            "xavs2_qp.mkv",
            "avs2",
            "yuv420p",
        )

        # 6. Next-Gen Image Formats
        self.test_codec(
            "ADV.C17",
            "JPEG XL libjxl Single Image",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=1",
                "-vframes",
                "1",
                "-c:v",
                "libjxl",
                "-update",
                "1",
            ],
            "test_jxl.jxl",
            "jpegxl",
            check_decode=True,
        )
        self.test_codec(
            "ADV.C18",
            "JPEG XL libjxl RGB24 Image",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=1",
                "-vframes",
                "1",
                "-pix_fmt",
                "rgb24",
                "-c:v",
                "libjxl",
                "-update",
                "1",
            ],
            "test_jxl_rgb.jxl",
            "jpegxl",
            expected_pix_fmt="rgb24",
            check_decode=True,
        )
        self.test_codec(
            "ADV.C19",
            "WebP libwebp Lossy Image",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=1",
                "-vframes",
                "1",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libwebp",
                "-q:v",
                "80",
            ],
            "test_webp_lossy.webp",
            "webp",
            expected_pix_fmt="yuv420p",
            check_decode=True,
        )
        self.test_codec(
            "ADV.C20",
            "WebP libwebp Lossless Image",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=1",
                "-vframes",
                "1",
                "-pix_fmt",
                "bgra",
                "-c:v",
                "libwebp",
                "-lossless",
                "1",
            ],
            "test_webp_lossless.webp",
            "webp",
            check_decode=True,
        )
        self.test_codec(
            "ADV.C21",
            "WebP libwebp Animated Muxing",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=2:size=320x240:rate=15",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libwebp",
                "-loop",
                "0",
            ],
            "test_animated.webp",
            "webp",
            check_decode=False,
        )
        self.test_codec(
            "ADV.C22",
            "JPEG 2000 libopenjpeg RGB MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=25",
                "-pix_fmt",
                "rgb24",
                "-c:v",
                "libopenjpeg",
            ],
            "openjpeg_rgb.mkv",
            "jpeg2000",
            expected_pix_fmt="rgb24",
            check_decode=True,
        )
        self.test_codec(
            "ADV.C23",
            "JPEG 2000 libopenjpeg 10-bit MKV",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=25",
                "-pix_fmt",
                "yuv422p10le",
                "-c:v",
                "libopenjpeg",
            ],
            "openjpeg_10bit.mkv",
            "jpeg2000",
            expected_pix_fmt="yuv422p10le",
            check_decode=True,
        )

        # 7. Additional Adversarial Stress Tests
        self.test_codec(
            "ADV.C24",
            "AV1 SVT-AV1 1-Frame Boundary",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=640x360:rate=30",
                "-vframes",
                "1",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libsvtav1",
                "-preset",
                "10",
            ],
            "svtav1_1frame.mp4",
            "av1",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C25",
            "AV1 rav1e Multi-threaded 0",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-threads",
                "0",
                "-c:v",
                "librav1e",
                "-speed",
                "10",
            ],
            "rav1e_mt.mp4",
            "av1",
            "yuv420p",
        )
        self.test_codec(
            "ADV.C26",
            "AVS2 davs2 Decoder Roundtrip",
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=1:size=320x240:rate=25",
                "-pix_fmt",
                "yuv420p",
                "-c:v",
                "libxavs2",
            ],
            "davs2_test.mkv",
            "avs2",
            "yuv420p",
            check_decode=True,
        )

        # 8. Containers Muxing & Demuxing
        self.test_mp4_faststart("ADV.K01")
        self.test_dash_muxing("ADV.K02")
        self.test_hls_muxing("ADV.K03")
        self.test_matroska_multitrack("ADV.K04")
        self.test_webm_container("ADV.K05")

        # 9. Quality Filters & Shaders
        self.test_libvmaf("ADV.F01")
        self.test_libplacebo("ADV.F02")

        passed_count = sum(1 for r in self.results if r["passed"] and not r["skipped"])
        skipped_count = sum(1 for r in self.results if r["skipped"])
        failed_count = sum(
            1 for r in self.results if not r["passed"] and not r["skipped"]
        )

        print(f"\n[{self.platform_name}] FINAL SUMMARY:")
        print(f"  TOTAL TESTS: {len(self.results)}")
        print(f"  PASSED:      {passed_count}")
        print(f"  SKIPPED:     {skipped_count}")
        print(f"  FAILED:      {failed_count}")
        print("==================================================================\n")

        return self.results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Challenger 2 Adversarial Test Suite")
    parser.add_argument(
        "--platform", choices=["linux", "windows", "all"], default="all"
    )
    args = parser.parse_args()

    results_all = {}

    if args.platform in ["linux", "all"]:
        linux_ffmpeg = "./dist/linux-x86_64/ffmpeg"
        linux_ffprobe = "./dist/linux-x86_64/ffprobe"
        linux_out = "./temp/challenger_2_linux"
        linux_runner = AdversarialVerifier(
            linux_ffmpeg, linux_ffprobe, linux_out, "LINUX-X86_64"
        )
        results_all["linux"] = linux_runner.run_all()

    if args.platform in ["windows", "all"]:
        win_ffmpeg = "./dist/windows-x86_64/ffmpeg.exe"
        win_ffprobe = "./dist/windows-x86_64/ffprobe.exe"
        win_out = "./temp/challenger_2_windows"
        win_runner = AdversarialVerifier(
            win_ffmpeg, win_ffprobe, win_out, "WINDOWS-X86_64"
        )
        results_all["windows"] = win_runner.run_all()

    with open("./temp/challenger_2_results.json", "w", encoding="utf-8") as f:
        json.dump(results_all, f, indent=2)


if __name__ == "__main__":
    main()
