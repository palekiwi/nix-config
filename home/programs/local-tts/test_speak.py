import io
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import speak


class InputTests(unittest.TestCase):
    def args(self, **kwargs):
        from argparse import Namespace

        return Namespace(text=[], file=None, clipboard=False, **kwargs)

    def test_positional_and_stdin(self):
        args = self.args()
        args.text = ["hello", "world"]
        self.assertEqual(speak.read_input(args, io.StringIO("ignored")), "hello world")
        self.assertEqual(
            speak.read_input(self.args(), io.StringIO("piped\ntext")), "piped\ntext"
        )

    def test_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.txt"
            path.write_text("café\nfile", encoding="utf-8")
            args = self.args()
            args.file = str(path)
            self.assertEqual(speak.read_input(args, io.StringIO()), "café\nfile")

    def test_clipboard_selection_and_failures(self):
        args = self.args()
        args.clipboard = True
        for env, expected in [
            ({"WAYLAND_DISPLAY": "wayland-0", "DISPLAY": ":0"}, "wl-paste"),
            ({"DISPLAY": ":0"}, "xclip"),
        ]:

            def clipboard(command, stdout):
                self.assertEqual(command[0], expected)
                stdout.write("clipboard café".encode())

            with (
                patch.dict(os.environ, env, clear=True),
                patch.object(speak, "run_child", side_effect=clipboard),
            ):
                self.assertEqual(
                    speak.read_input(args, io.StringIO()), "clipboard café"
                )
        with (
            patch.dict(os.environ, {}, clear=True),
            self.assertRaisesRegex(ValueError, "session"),
        ):
            speak.read_input(args, io.StringIO())
        with (
            patch.dict(os.environ, {"DISPLAY": ":0"}, clear=True),
            patch.object(
                speak,
                "run_child",
                side_effect=subprocess.CalledProcessError(1, "xclip"),
            ),
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                speak.read_input(args, io.StringIO())

    def test_tty_and_empty_input(self):
        stream = io.StringIO()
        stream.isatty = lambda: True
        with self.assertRaisesRegex(ValueError, "provide text"):
            speak.read_input(self.args(), stream)
        with (
            patch("sys.stdin", io.StringIO("  \n")),
            patch.object(speak, "generate") as generate,
        ):
            self.assertEqual(speak.main([]), 1)
            generate.assert_not_called()

    def test_conflicting_sources(self):
        for argv in [
            ["text", "--file", "x"],
            ["text", "--clipboard"],
            ["--file", "x", "--clipboard"],
        ]:
            with self.assertRaises(SystemExit) as error:
                speak.main(argv)
            self.assertEqual(error.exception.code, 2)

    def test_raw_and_output_skip_playback(self):
        def generate(text, output):
            self.assertEqual(text, "# raw")
            output.write_bytes(b"wave")

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(speak, "generate", side_effect=generate),
            patch.object(speak, "playback") as playback,
        ):
            output = Path(directory) / "out.wav"
            self.assertEqual(speak.main(["--raw", "--output", str(output), "# raw"]), 0)
            self.assertEqual(output.read_bytes(), b"wave")
            playback.assert_not_called()


class CleanupTests(unittest.TestCase):
    def test_markdown_preserves_content(self):
        text = "# Heading\n- Read `path/a.py`\n> [Docs](https://example.com)\n![diagram](image.png)\n```python\nprint('hello')\n# code heading\n```\nAfter **important** text."
        self.assertEqual(
            speak.clean_markdown(text),
            "Heading\nRead path/a.py\nDocs (https://example.com)\ndiagram (image.png)\nprint('hello')\n# code heading\nAfter **important** text.",
        )

    def test_inline_triple_backticks_not_dropped(self):
        self.assertEqual(speak.clean_markdown("```keep me```"), "keep me")

    def test_unfamiliar_markup_not_dropped(self):
        text = "<details>\nsecret text\n</details>\n| a | b |\n1. first\nhttps://example.com/a_b\n~~~sh\necho preserved"
        self.assertEqual(speak.clean_markdown(text), text.replace("~~~sh\n", ""))


class EngineTests(unittest.TestCase):
    def test_engine_boundary_and_leading_dashes(self):
        with (
            patch.dict(os.environ, {"SPEAK_MODEL": "/model"}),
            patch.object(speak, "run_child") as run,
        ):
            speak.generate("--all text", Path("/tmp/audio.wav"))
            command = run.call_args.args[0]
            self.assertEqual(command[-2:], ["--", "--all text"])
            self.assertIn("--sid=1", command)
            self.assertIn("--provider=cpu", command)
            self.assertIn("--output-filename=/tmp/audio.wav", command)

    def test_generation_failure_does_not_play_and_removes_temp(self):
        paths = []

        def fail(text, output):
            paths.append(output.parent)
            raise subprocess.CalledProcessError(1, "engine")

        with (
            patch.object(speak, "generate", side_effect=fail),
            patch.object(speak, "playback") as playback,
        ):
            self.assertEqual(speak.main(["hello"]), 1)
            playback.assert_not_called()
        self.assertFalse(paths[0].exists())


class LifecycleTests(unittest.TestCase):
    def wait_for(self, condition):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.02)
        self.fail("timed out waiting for subprocess")

    def test_nonzero_child_fails(self):
        with self.assertRaises(subprocess.CalledProcessError):
            speak.run_child([sys.executable, "-c", "raise SystemExit(7)"])

    def test_interrupt_generation_and_playback_descendants(self):
        for stage in ("generation", "playback"):
            for sig in (signal.SIGINT, signal.SIGTERM):
                with (
                    self.subTest(stage=stage, signal=sig),
                    tempfile.TemporaryDirectory() as directory,
                ):
                    root = Path(directory)
                    fake = root / "fake.py"
                    fake.write_text(
                        "import os, pathlib, signal, subprocess, sys, time\n"
                        "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                        "signal.signal(signal.SIGINT, signal.SIG_IGN)\n"
                        "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])\n"
                        "pathlib.Path(sys.argv[1]).write_text(str(os.getpid()) + ' ' + str(child.pid))\n"
                        "time.sleep(60)\n"
                    )
                    runner = root / "runner.py"
                    runner.write_text(
                        "import pathlib, sys\n"
                        f"sys.path.insert(0, {str(Path(speak.__file__).parent)!r})\n"
                        "import speak\n"
                        f"command = [{sys.executable!r}, {str(fake)!r}, {str(root / 'pids')!r}]\n"
                        f"stage = {stage!r}\n"
                        "def generate(text, output):\n"
                        "    pathlib.Path(output).write_bytes(b'wave')\n"
                        "    if stage == 'generation': speak.run_child(command)\n"
                        "def playback(output):\n"
                        "    if stage == 'playback': speak.run_child(command)\n"
                        "speak.generate = generate\n"
                        "speak.playback = playback\n"
                        "raise SystemExit(speak.main(['hello']))\n"
                    )
                    process = subprocess.Popen(
                        [sys.executable, str(runner)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    pids = []
                    try:
                        self.wait_for(lambda: (root / "pids").exists())
                        pids = [int(pid) for pid in (root / "pids").read_text().split()]
                        process.send_signal(sig)
                        self.assertEqual(process.wait(timeout=5), 130)

                        def stopped():
                            for pid in pids:
                                try:
                                    state = (
                                        Path(f"/proc/{pid}/stat")
                                        .read_text()
                                        .split(") ", 1)[1]
                                        .split()[0]
                                    )
                                except FileNotFoundError:
                                    continue
                                if state != "Z":
                                    return False
                            return True

                        self.wait_for(stopped)
                    finally:
                        process.kill() if process.poll() is None else None
                        process.wait()
                        for pid in pids:
                            try:
                                os.kill(pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass


if __name__ == "__main__":
    unittest.main()
