import argparse
import os
import re
import subprocess
import sys


def get_enabled_features(ffmpeg_path):
    """Obtiene los flags --enable-* de la configuración de ffmpeg."""
    print("[1] Obteniendo configuración de FFmpeg...")
    try:
        result = subprocess.run(
            [ffmpeg_path, "-version"], capture_output=True, text=True, check=True
        )
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


def get_tests(test_dir):
    """
    Define las pruebas para cada feature.
    Usa 'lavfi' (testsrc/aevalsrc) para generar video/audio sin requerir archivos externos.
    """
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
            os.path.join(test_dir, "test_x264.mp4"),
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
            os.path.join(test_dir, "test_x265.mp4"),
        ],
        "libvpx": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libvpx-vp9",
            os.path.join(test_dir, "test_vp9.webm"),
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
            os.path.join(test_dir, "test_av1.mkv"),
        ],
        "libsvtav1": [
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=640x360:rate=30",
            "-c:v",
            "libsvtav1",
            os.path.join(test_dir, "test_svtav1.mp4"),
        ],
        "libmp3lame": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libmp3lame",
            os.path.join(test_dir, "test_lame.mp3"),
        ],
        "libopus": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libopus",
            os.path.join(test_dir, "test_opus.mkv"),
        ],
        "libvorbis": [
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=0:duration=1",
            "-c:a",
            "libvorbis",
            os.path.join(test_dir, "test_vorbis.ogg"),
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
            "vidstabdetect=result=transform.trf",
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
            os.path.join(test_dir, "test_nvenc.mp4"),
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
            os.path.join(test_dir, "test_vaapi.mp4"),
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
    }


def run_tests(ffmpeg_path, test_dir, features):
    os.makedirs(test_dir, exist_ok=True)
    tests = get_tests(test_dir)
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

            log.write(
                f"\n{'=' * 50}\nTEST: {test_name}\nCMD: {' '.join(cmd)}\n{'=' * 50}\n"
            )

            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    print("OK")
                    log.write("STATUS: EXIT_SUCCESS\n")
                else:
                    hw_errors = ["No device available for decoder", "Driver does not support", "Function not implemented", "Failed to initialise VAAPI", "unknown libva error", "could not load the shared library"]
                    if any(err in result.stderr for err in hw_errors):
                        print(f"SKIPPED (No HW, Code: {result.returncode})")
                        log.write(f"STATUS: SKIPPED (Hardware not available) with code {result.returncode}\n")
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

    if not os.path.isfile(args.ffmpeg_path) or not os.access(args.ffmpeg_path, os.X_OK):
        print(f"Error: {args.ffmpeg_path} no existe o no es ejecutable.")
        sys.exit(1)

    features = get_enabled_features(args.ffmpeg_path)
    run_tests(args.ffmpeg_path, args.test_dir, features)

    print(
        "\n[3] Pruebas finalizadas. Revisa el archivo 'ffmpeg_test_results.log' en tu directorio de pruebas."
    )
