"""
Extended Adversarial Stress & Concurrency Test Suite
Challenger 2 - Deep Stress & Verification
"""

import json
import os
import subprocess
import time


def run_stress(target_os="linux"):
    root_dir = os.path.abspath(".")
    if target_os == "linux":
        ffmpeg = os.path.join(root_dir, "dist/linux-x86_64/ffmpeg")
        ffprobe = os.path.join(root_dir, "dist/linux-x86_64/ffprobe")
        cmd_prefix = []
        env = os.environ.copy()
    else:
        ffmpeg = os.path.join(root_dir, "dist/windows-x86_64/ffmpeg.exe")
        ffprobe = os.path.join(root_dir, "dist/windows-x86_64/ffprobe.exe")  # noqa: F841
        cmd_prefix = ["wine"]
        env = dict(os.environ, WINEDEBUG="-all")

    out_dir = os.path.abspath(f"./temp/stress_{target_os}")
    manifest_dir = os.path.abspath(f"./temp/challenger_2_{target_os}")
    os.makedirs(out_dir, exist_ok=True)
    results = []

    def exec_cmd(args, timeout=60, cwd=None):
        start = time.time()
        p = subprocess.run(
            cmd_prefix + args,
            check=False, capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            cwd=cwd,
        )
        return p.returncode, p.stdout, p.stderr, time.time() - start

    print("\n========================================================")
    print(f" EXTENDED ADVERSARIAL STRESS SUITE: {target_os.upper()}")
    print("========================================================")

    # 1. Stress: Multithreaded SVT-AV1 High-throughput
    t1_out = os.path.join(out_dir, "svtav1_stress_hd.mp4")
    ret, _out, _err, dur = exec_cmd(
        [
            ffmpeg,
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=3:size=1920x1080:rate=60",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libsvtav1",
            "-preset",
            "8",
            "-threads",
            "0",
            t1_out,
        ],
        timeout=90,
    )
    passed1 = ret == 0 and os.path.exists(t1_out) and os.path.getsize(t1_out) > 0
    print(
        f"[{target_os.upper()}] [{'PASS' if passed1 else 'FAIL'}] STRESS.01 - 1080p60 Multi-threaded SVT-AV1 ({dur:.2f}s, size={os.path.getsize(t1_out) if passed1 else 0}B)"
    )
    results.append(("STRESS.01", "1080p60 Multi-threaded SVT-AV1", passed1, dur))

    # 2. Stress: DASH Playback / Demuxing Test
    ret, _out, _err, dur = exec_cmd(
        [ffmpeg, "-y", "-i", "test_manifest.mpd", "-t", "1", "-f", "null", "-"],
        timeout=30,
        cwd=manifest_dir,
    )
    passed2 = ret == 0
    print(
        f"[{target_os.upper()}] [{'PASS' if passed2 else 'FAIL'}] STRESS.02 - DASH Manifest Demuxing & Decoding ({dur:.2f}s)"
    )
    results.append(("STRESS.02", "DASH Manifest Demuxing & Decoding", passed2, dur))

    # 3. Stress: HLS Playlist Demuxing & Decoding
    hls_in = os.path.join(manifest_dir, "test_hls_ts.m3u8")
    ret, _out, _err, dur = exec_cmd(
        [ffmpeg, "-y", "-i", hls_in, "-t", "1", "-f", "null", "-"], timeout=30
    )
    passed3 = ret == 0
    print(
        f"[{target_os.upper()}] [{'PASS' if passed3 else 'FAIL'}] STRESS.03 - HLS Playlist Demuxing & Decoding ({dur:.2f}s)"
    )
    results.append(("STRESS.03", "HLS Playlist Demuxing & Decoding", passed3, dur))

    # 4. Stress: Matroska Stream Extraction
    mkv_in = os.path.join(manifest_dir, "test_complex_multitrack.mkv")
    sub_out = os.path.join(out_dir, "extracted_sub.ass")
    ret, _out, _err, dur = exec_cmd(
        [ffmpeg, "-y", "-i", mkv_in, "-map", "0:s:0", "-c:s", "copy", sub_out],
        timeout=30,
    )
    passed4 = ret == 0 and os.path.exists(sub_out) and os.path.getsize(sub_out) > 0
    print(
        f"[{target_os.upper()}] [{'PASS' if passed4 else 'FAIL'}] STRESS.04 - Matroska Subtitle Demux/Extraction ({dur:.2f}s)"
    )
    results.append(("STRESS.04", "Matroska Subtitle Demux/Extraction", passed4, dur))

    # 5. Stress: Real VMAF Score on Compressed Stream
    vmaf_log = os.path.join(out_dir, "vmaf_distorted.json")
    ret, _out, _err, dur = exec_cmd(
        [
            ffmpeg,
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=640x360:rate=25",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=640x360:rate=25,scale=320:180,scale=640:360",
            "-filter_complex",
            f"[0:v][1:v]libvmaf=log_fmt=json:log_path={vmaf_log}",
            "-f",
            "null",
            "-",
        ],
        timeout=45,
    )
    score = None
    if os.path.exists(vmaf_log):
        try:
            with open(vmaf_log) as f:
                d = json.load(f)
                score = d.get("pooled_metrics", {}).get("vmaf", {}).get("mean")
        except Exception as e:
            print(f"Error reading VMAF log: {e}")
    passed5 = ret == 0 and score is not None and 0.0 <= score <= 100.0
    print(
        f"[{target_os.upper()}] [{'PASS' if passed5 else 'FAIL'}] STRESS.05 - VMAF Built-in Model Metric Calculation (Score: {score:.2f} / 100, {dur:.2f}s)"
    )
    results.append(("STRESS.05", "VMAF Built-in Metric Calculation", passed5, dur))

    # 6. Stress: libplacebo Multiple Shader Operations
    placebo_out = os.path.join(out_dir, "placebo_advanced.mp4")
    ret, _out, _err, dur = exec_cmd(
        [
            ffmpeg,
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-vf",
            "libplacebo=w=1280:h=720:upscaler=ewa_lanczos:tonemapping=bt.2446a:deband=true",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            placebo_out,
        ],
        timeout=60,
    )
    passed6 = (
        ret == 0 and os.path.exists(placebo_out) and os.path.getsize(placebo_out) > 0
    )
    print(
        f"[{target_os.upper()}] [{'PASS' if passed6 else 'FAIL'}] STRESS.06 - libplacebo Advanced Shader Filters (EWA-Lanczos + Tonemap) ({dur:.2f}s)"
    )
    results.append(("STRESS.06", "libplacebo Advanced Shader Filters", passed6, dur))

    all_passed = all(r[2] for r in results)
    print(
        f"\n[{target_os.upper()}] STRESS SUMMARY: {'ALL PASSED (6/6)' if all_passed else 'SOME FAILED'}\n"
    )
    return results


if __name__ == "__main__":
    r_linux = run_stress("linux")
    r_win = run_stress("windows")
