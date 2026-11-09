import argparse
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


class Cancelled(Exception):
    pass


def run_child(argv, **kwargs):
    cancelled = False

    def cancel(signum, frame):
        nonlocal cancelled
        cancelled = True

    previous = {
        sig: signal.signal(sig, cancel) for sig in (signal.SIGINT, signal.SIGTERM)
    }
    process = None
    try:
        process = subprocess.Popen(argv, start_new_session=True, **kwargs)
        while not cancelled:
            try:
                code = process.wait(timeout=0.1)
                if cancelled:
                    break
                if code:
                    raise subprocess.CalledProcessError(code, argv)
                return
            except subprocess.TimeoutExpired:
                pass
        raise Cancelled()
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def clean_markdown(text):
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.fullmatch(r" {0,3}(`{3,}|~{3,})(.*)", line)
        if fence is not None:
            if (
                marker
                and marker[1][0] == fence[0]
                and len(marker[1]) >= len(fence)
                and not marker[2].strip()
            ):
                fence = None
            else:
                lines.append(line)
            continue
        if marker and re.fullmatch(r"[ \t]*[\w.+#/-]*[ \t]*", marker[2]):
            fence = marker[1]
            continue
        line = re.sub(r"^ {0,3}#{1,6}\s+", "", line)
        line = re.sub(r"^\s*>\s?", "", line)
        line = re.sub(r"^(\s*)[-+*]\s+", r"\1", line)
        line = re.sub(r"!?\[([^\]\n]*)\]\(([^)\n]+)\)", r"\1 (\2)", line)
        line = re.sub(r"(`+)(.+?)\1", r"\2", line)
        lines.append(line)
    return "\n".join(lines).strip()


def read_input(args, stdin):
    if args.text:
        return " ".join(args.text)
    if args.file is not None:
        return Path(args.file).read_text(encoding="utf-8")
    if args.clipboard:
        if os.environ.get("WAYLAND_DISPLAY"):
            command = [
                os.environ.get("SPEAK_WL_PASTE", "wl-paste"),
                "--no-newline",
                "--type",
                "text",
            ]
        elif os.environ.get("DISPLAY"):
            command = [
                os.environ.get("SPEAK_XCLIP", "xclip"),
                "-selection",
                "clipboard",
                "-out",
            ]
        else:
            raise ValueError("clipboard requires a Wayland or X11 session")
        with tempfile.TemporaryFile() as output:
            run_child(command, stdout=output)
            output.seek(0)
            return output.read().decode("utf-8")
    if stdin.isatty():
        raise ValueError("provide text, piped stdin, --file PATH, or --clipboard")
    return stdin.read()


def generate(text, output):
    model = Path(os.environ["SPEAK_MODEL"])
    command = [
        os.environ.get("SPEAK_ENGINE", "sherpa-onnx-offline-tts"),
        "--provider=cpu",
        "--num-threads=4",
        f"--kokoro-model={model}/model.int8.onnx",
        f"--kokoro-voices={model}/voices.bin",
        f"--kokoro-tokens={model}/tokens.txt",
        f"--kokoro-data-dir={model}/espeak-ng-data",
        "--kokoro-length-scale=1",
        "--tts-max-num-sentences=1",
        "--tts-silence-scale=0.2",
        "--sid=1",
        f"--output-filename={output}",
        "--",
        text,
    ]
    run_child(command, stdout=sys.stderr)


def playback(output):
    run_child([os.environ.get("SPEAK_PLAYER", "pw-play"), str(output)])


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Foreground local Bella CPU speech (whole-file, not streaming)."
    )
    parser.add_argument(
        "text", nargs="*", help="text to speak (use -- before leading dashes)"
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--file", metavar="PATH", help="read a UTF-8 file")
    source.add_argument("--clipboard", action="store_true", help="read clipboard once")
    parser.add_argument("--raw", action="store_true", help="skip Markdown cleanup")
    parser.add_argument(
        "--output", metavar="WAV", help="generate a WAV instead of playing it"
    )
    args = parser.parse_args(argv)
    if args.text and (args.file is not None or args.clipboard):
        parser.error("positional text cannot be combined with --file or --clipboard")
    try:
        text = read_input(args, sys.stdin)
        if not args.raw:
            text = clean_markdown(text)
        if not text.strip():
            raise ValueError("input contains no text to speak")
        with tempfile.TemporaryDirectory(prefix="speak-") as directory:
            output = Path(directory) / "speech.wav"
            started = time.monotonic()
            generate(text, output)
            print(
                f"speak: whole-file generation {time.monotonic() - started:.2f}s",
                file=sys.stderr,
            )
            if args.output:
                shutil.copyfile(output, args.output)
            else:
                playback(output)
        return 0
    except (KeyboardInterrupt, Cancelled):
        print("speak: cancelled", file=sys.stderr)
        return 130
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"speak: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
