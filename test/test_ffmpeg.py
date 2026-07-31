import argparse
import os
import re
import subprocess
import sys


def get_enabled_features(ffmpeg_path):
    """Obtiene los flags --enable-* de la configuración de ffmpeg."""
    print("[1] Obteniendo configuración de FFmpeg...")
    is_android = "android" in ffmpeg_path.lower()
    try:
        cmd = [ffmpeg_path, "-version"]
        if ffmpeg_path.endswith(".exe"):
            cmd = ["wine"] + cmd
        elif is_android:
            cmd = ["adb", "shell", "/data/local/tmp/ffmpeg", "-version"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error fatal al ejecutar ffmpeg -version: Código {e.returncode}")
        sys.exit(1)

    match = re.search(r"configuration:\s*(.*)", result.stdout)
    if not match:
        print("No se encontró la línea de configuración.")
        return []

    config_line = match.group(1)
    features = [
        f.split("=")[0].replace("--enable-", "")
        for f in config_line.split()
        if f.startswith("--enable-")
    ]
    return features


def get_tests(test_dir, is_android=False):
    """
    Define las pruebas para cada feature.
    Usa 'lavfi' (testsrc/aevalsrc) para generar video/audio sin requerir archivos externos.
    """
    output_dir = "/data/local/tmp" if is_android else test_dir
    return {
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
        "libvidstab": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-vf",
            f"vidstabdetect=result={os.path.join(output_dir, 'transform.trf')}",
            "-f",
            "null",
            "-",
        ],
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
        "libtheora": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libtheora",
            os.path.join(output_dir, "test_theora.ogg"),
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
        "libopenh264": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libopenh264",
            os.path.join(output_dir, "test_openh264.mp4"),
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
        "libxvid": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libxvid",
            os.path.join(output_dir, "test_xvid.avi"),
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
        "libkvazaar": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libkvazaar",
            os.path.join(output_dir, "test_kvazaar.mp4"),
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
        "chromaprint": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-f",
            "chromaprint",
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
    }


def run_tests(ffmpeg_path, test_dir, features):
    is_android = "android" in ffmpeg_path.lower()
    os.makedirs(test_dir, exist_ok=True)
    tests = get_tests(test_dir, is_android)
    log_file = os.path.join(test_dir, "ffmpeg_test_results.log")

    # Pruebas a ejecutar (Las básicas siempre, más las que coincidan con la compilación)
    tests_to_run = ["basic_video", "basic_audio"]
    for f in features:
        if f in tests:
            tests_to_run.append(f)

    print(
        f"\n[2] Ejecutando {len(tests_to_run)} pruebas. Logs guardados en {log_file}...\n"
    )

    with open(log_file, "w") as log:
        for test_name in tests_to_run:
            print(f"Probando {test_name.ljust(15)} ... ", end="", flush=True)
            cmd = [ffmpeg_path, "-y", "-v", "error"] + tests[test_name]
            if ffmpeg_path.endswith(".exe"):
                cmd = ["wine"] + cmd
            elif is_android:
                cmd = [
                    "adb",
                    "shell",
                    "/data/local/tmp/ffmpeg",
                    "-y",
                    "-v",
                    "error",
                ] + tests[test_name]

            log.write(
                f"\n{'=' * 50}\nTEST: {test_name}\nCMD: {' '.join(cmd)}\n{'=' * 50}\n"
            )

            try:
                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=60, check=False
                )
                if result.returncode == 0:
                    print("OK")
                    log.write("STATUS: EXIT_SUCCESS\n")
                else:
                    hw_errors = [
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
                    ]
                    if any(err in result.stderr for err in hw_errors):
                        print(f"SKIPPED (No HW, Code: {result.returncode})")
                        log.write(
                            f"STATUS: SKIPPED (Hardware not available) with code {result.returncode}\n"
                        )
                        log.write(f"STDERR:\n{result.stderr}\n")
                    else:
                        print(f"FAIL (Code: {result.returncode})")
                        log.write(f"STATUS: FAILED with code {result.returncode}\n")
                        log.write(f"STDERR:\n{result.stderr}\n")
            except subprocess.TimeoutExpired:
                print("TIMEOUT")
                log.write("STATUS: TIMEOUT (10 seconds)\n")
            except Exception as e:
                print("ERROR")
                log.write(f"STATUS: FATAL ERROR\n{e!s}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FFmpeg Build Tester")
    parser.add_argument("ffmpeg_path", help="Ruta absoluta al ejecutable ffmpeg")
    parser.add_argument(
        "test_dir", help="Directorio donde guardar los archivos de prueba y logs"
    )

    args = parser.parse_args()

    if not os.path.isfile(args.ffmpeg_path):
        print(f"Error: {args.ffmpeg_path} no existe.")
        sys.exit(1)

    if "android" in args.ffmpeg_path.lower():
        print("[0] Preparando dispositivo Android (ADB)...")
        subprocess.run(
            ["adb", "push", args.ffmpeg_path, "/data/local/tmp/ffmpeg"], check=True
        )
        subprocess.run(
            ["adb", "shell", "chmod", "+x", "/data/local/tmp/ffmpeg"], check=True
        )

    features = get_enabled_features(args.ffmpeg_path)
    run_tests(args.ffmpeg_path, args.test_dir, features)

    print(
        "\n[3] Pruebas finalizadas. Revisa el archivo 'ffmpeg_test_results.log' en tu directorio de pruebas."
    )
