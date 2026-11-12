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
    run_children([(argv, kwargs)])


def run_children(commands, pipeline=False):
    cancelled = False

    def cancel(signum, frame):
        nonlocal cancelled
        cancelled = True

    previous = {
        sig: signal.signal(sig, cancel) for sig in (signal.SIGINT, signal.SIGTERM)
    }
    processes = []
    try:
        for index, (argv, options) in enumerate(commands):
            kwargs = dict(options)
            if pipeline:
                if index == 0:
                    kwargs["stdin"] = subprocess.PIPE
                else:
                    kwargs["stdout"] = processes[0].stdin
            processes.append(subprocess.Popen(argv, start_new_session=True, **kwargs))
        if pipeline:
            processes[0].stdin.close()
        while not cancelled:
            codes = [process.poll() for process in processes]
            if cancelled:
                break
            for process, code in zip(processes, codes):
                if code:
                    raise subprocess.CalledProcessError(code, process.args)
            if all(code is not None for code in codes):
                return
            time.sleep(0.02)
        raise Cancelled()
    finally:
        for process in processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 0.5
        for process in processes:
            try:
                process.wait(timeout=max(0, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                pass
        for process in processes:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            if pipeline and process.stdin is not None:
                process.stdin.close()
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


def synthesize(text, output=None, verbose=False):
    backend = os.environ.get("SPEAK_BACKEND", "cpu")
    if backend == "http":
        command = [
            sys.executable,
            str(Path(__file__).with_name("http_engine.py")),
            str(output) if output is not None else "-",
        ]
    elif backend == "cpu":
        command = [
            os.environ.get("SPEAK_ENGINE", "speak-engine"),
            os.environ["SPEAK_MODEL"],
            str(output) if output is not None else "-",
            "1" if verbose else "0",
        ]
    else:
        raise ValueError("SPEAK_BACKEND must be cpu or http")
    with tempfile.TemporaryFile() as source, tempfile.TemporaryFile() as diagnostics:
        source.write(text.encode("utf-8"))
        source.seek(0)
        options = {"stdin": source, "stderr": sys.stderr if verbose else diagnostics}
        commands = [(command, options)]
        if output is None:
            player = [
                os.environ.get("SPEAK_PLAYER", "pw-play"),
                "--raw",
                "--format=s16" if backend == "http" else "--format=f32",
                "--rate=24000",
                "--channels=1",
                f"--volume={os.environ.get('SPEAK_VOLUME', '1')}",
                "--properties={ application.name = speak state.restore-props = false }",
                "-",
            ]
            commands.insert(0, (player, {"stderr": options["stderr"]}))
        try:
            run_children(commands, pipeline=output is None)
        except subprocess.CalledProcessError:
            if not verbose:
                diagnostics.seek(0, os.SEEK_END)
                size = diagnostics.tell()
                diagnostics.seek(max(0, size - 8192))
                message = diagnostics.read().decode("utf-8", errors="replace")
                if message:
                    print(message.rstrip(), file=sys.stderr)
            raise


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Foreground local Bella speech with streaming playback."
    )
    parser.add_argument(
        "text", nargs="*", help="text to speak (use -- before leading dashes)"
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--file", metavar="PATH", help="read a UTF-8 file")
    source.add_argument("--clipboard", action="store_true", help="read clipboard once")
    parser.add_argument("--raw", action="store_true", help="skip Markdown cleanup")
    parser.add_argument(
        "--backend",
        choices=("cpu", "http"),
        help="explicit backend (no automatic fallback)",
    )
    parser.add_argument(
        "--output", metavar="WAV", help="generate a WAV instead of playing it"
    )
    parser.add_argument(
        "--verbose", action="store_true", help="show engine diagnostics and timing"
    )
    args = parser.parse_args(argv)
    if args.text and (args.file is not None or args.clipboard):
        parser.error("positional text cannot be combined with --file or --clipboard")
    try:
        if args.backend:
            os.environ["SPEAK_BACKEND"] = args.backend
        text = read_input(args, sys.stdin)
        if not args.raw:
            text = clean_markdown(text)
        if not text.strip():
            raise ValueError("input contains no text to speak")
        with tempfile.TemporaryDirectory(prefix="speak-") as directory:
            output = Path(directory) / "speech.wav"
            started = time.monotonic()
            synthesize(text, output if args.output else None, args.verbose)
            if args.verbose:
                print(
                    f"speak: request completed in {time.monotonic() - started:.2f}s",
                    file=sys.stderr,
                )
            if args.output:
                destination = Path(args.output)
                with tempfile.NamedTemporaryFile(
                    prefix=".speak-", dir=destination.absolute().parent, delete=False
                ) as staging:
                    staged = Path(staging.name)
                try:
                    shutil.copyfile(output, staged)
                    os.replace(staged, destination)
                finally:
                    staged.unlink(missing_ok=True)
        return 0
    except (KeyboardInterrupt, Cancelled):
        print("speak: cancelled", file=sys.stderr)
        return 130
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"speak: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
