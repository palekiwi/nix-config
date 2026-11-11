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
            patch.object(speak, "synthesize") as generate,
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
        def generate(text, output, verbose):
            self.assertEqual(text, "# raw")
            self.assertFalse(verbose)
            output.write_bytes(b"wave")

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(speak, "synthesize", side_effect=generate),
        ):
            output = Path(directory) / "out.wav"
            self.assertEqual(speak.main(["--raw", "--output", str(output), "# raw"]), 0)
            self.assertEqual(output.read_bytes(), b"wave")


class OutputTests(unittest.TestCase):
    def test_publish_failure_preserves_destination_and_cleans_staging(self):
        def generate(text, output, verbose):
            output.write_bytes(b"complete wave")

        def fail_copy(source, destination):
            Path(destination).write_bytes(b"partial")
            raise OSError("disk full")

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(speak, "synthesize", side_effect=generate),
            patch.object(speak.shutil, "copyfile", side_effect=fail_copy),
        ):
            output = Path(directory) / "out.wav"
            output.write_bytes(b"old")
            self.assertEqual(speak.main(["--output", str(output), "hello"]), 1)
            self.assertEqual(output.read_bytes(), b"old")
            self.assertEqual(list(Path(directory).iterdir()), [output])


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
            patch.object(speak, "run_children") as run,
        ):
            speak.synthesize("--all text", Path("/tmp/audio.wav"))
            command = run.call_args.args[0][0][0]
            self.assertEqual(command, ["speak-engine", "/model", "/tmp/audio.wav", "0"])
            self.assertNotIn("--all text", command)
            self.assertFalse(run.call_args.kwargs["pipeline"])

    def test_generation_failure_does_not_play_and_removes_temp(self):
        paths = []

        def fail(text, output, verbose):
            paths.append(output.parent)
            raise subprocess.CalledProcessError(1, "engine")

        with (
            patch.object(speak, "synthesize", side_effect=fail),
        ):
            self.assertEqual(speak.main(["--output", "/unused.wav", "hello"]), 1)
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
                        "def synthesize(text, output, verbose):\n"
                        "    speak.run_child(command)\n"
                        "speak.synthesize = synthesize\n"
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


class PipelineTests(unittest.TestCase):
    wait_for = LifecycleTests.wait_for

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env = dict(os.environ, SPEAK_MODEL="/model", TEST_ROOT=str(self.root))
        self.engine = self.script("engine", "")
        self.player = self.script("player", "")
        self.env.update(SPEAK_ENGINE=str(self.engine), SPEAK_PLAYER=str(self.player))

    def script(self, name, body):
        path = self.root / name
        path.write_text(
            f"#!{sys.executable}\n"
            "import os, pathlib, signal, subprocess, sys, time\n"
            "root = pathlib.Path(os.environ['TEST_ROOT'])\n"
            "def wait(name):\n"
            "    deadline = time.monotonic() + 8\n"
            "    while not (root / name).exists():\n"
            "        if time.monotonic() > deadline: raise RuntimeError(name)\n"
            "        time.sleep(0.01)\n" + body
        )
        path.chmod(0o755)
        return path

    def start(self, *args):
        process = subprocess.Popen(
            [sys.executable, str(Path(speak.__file__)), *args, "private input"],
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(self.stop, process)
        return process

    def stop(self, process):
        if process.poll() is None:
            process.terminate()
        process.communicate(timeout=5)

    def test_first_audio_before_completion_and_bounded_pipe(self):
        self.script(
            "engine",
            "assert sys.stdin.read() == 'private input'\n"
            "print('noisy private input', file=sys.stderr)\n"
            "os.write(1, b'abcd')\n"
            "wait('received')\n"
            "(root / 'writing').touch()\n"
            "data = b'x' * (4 * 1024 * 1024)\n"
            "while data:\n"
            "    count = os.write(1, data)\n"
            "    data = data[count:]\n"
            "(root / 'generated').touch()\n",
        )
        self.script(
            "player",
            "assert '--raw' in sys.argv and '--format=f32' in sys.argv\n"
            "assert os.read(0, 4) == b'abcd'\n"
            "assert not (root / 'generated').exists()\n"
            "(root / 'received').touch()\n"
            "wait('drain')\n"
            "size = len(sys.stdin.buffer.read())\n"
            "assert size == 4 * 1024 * 1024\n",
        )
        process = self.start()
        self.wait_for(lambda: (self.root / "writing").exists())
        time.sleep(0.15)
        self.assertFalse((self.root / "generated").exists())
        self.assertIsNone(process.poll())
        (self.root / "drain").touch()
        out, err = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, err)
        self.assertEqual((out, err), (b"", b""))
        self.assertTrue((self.root / "generated").exists())

    def test_player_stream_identity_and_volume(self):
        self.script("engine", "sys.stdin.read()\n")
        self.script(
            "player",
            "(root / 'argv').write_text('\\n'.join(sys.argv[1:]))\n"
            "sys.stdin.buffer.read()\n",
        )
        for env, volume in (({}, "--volume=1"), ({"SPEAK_VOLUME": "2.5"}, "--volume=2.5")):
            self.env.pop("SPEAK_VOLUME", None)
            self.env.update(env)
            process = self.start()
            out, err = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, err)
            argv = (self.root / "argv").read_text().split("\n")
            self.assertIn(volume, argv)
            self.assertIn("--properties={ application.name = speak state.restore-props = false }", argv)

    def test_cancel_callback_blocked_on_pipe(self):
        self.script(
            "engine",
            "(root / 'engine.pid').write_text(str(os.getpid()))\n"
            "wait('player.pid')\n"
            "data = b'x' * (4 * 1024 * 1024)\n"
            "while data:\n"
            "    count = os.write(1, data)\n"
            "    data = data[count:]\n"
            "(root / 'generated').touch()\n",
        )
        self.script(
            "player",
            "(root / 'player.pid').write_text(str(os.getpid()))\ntime.sleep(60)\n",
        )
        process = self.start()
        self.wait_for(
            lambda: all(
                (self.root / (n + ".pid")).exists() for n in ("engine", "player")
            )
        )
        time.sleep(0.15)
        self.assertFalse((self.root / "generated").exists())
        process.send_signal(signal.SIGINT)
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 130, err)
        for name in ("engine", "player"):
            pid = (self.root / (name + ".pid")).read_text()
            self.assertFalse(Path(f"/proc/{pid}").exists())

    def test_failed_output_preserves_existing_file(self):
        self.script("engine", "raise SystemExit(7)\n")
        output = self.root / "out.wav"
        output.write_bytes(b"existing wave")
        process = self.start("--output", str(output))
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 1, err)
        self.assertEqual(output.read_bytes(), b"existing wave")

    def test_pipeline_failures_stop_peer(self):
        for stage in ("engine", "player"):
            with self.subTest(stage=stage):
                for name in ("engine", "player"):
                    self.script(
                        name,
                        "print('useful failure', file=sys.stderr)\nraise SystemExit(7)\n"
                        if name == stage
                        else "time.sleep(60)\n",
                    )
                process = self.start()
                out, err = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 1)
                self.assertIn(b"useful failure", err)
                self.assertNotIn(b"private input", err)
                self.assertEqual(out, b"")

    def test_output_complete_and_verbose(self):
        self.script(
            "engine",
            "assert sys.stdin.read() == 'private input'\n"
            "assert sys.argv[3] == '1'\n"
            "print('diagnostic', file=sys.stderr)\n"
            "pathlib.Path(sys.argv[2]).write_bytes(b'complete wave')\n",
        )
        self.script("player", "raise RuntimeError('must not play')\n")
        output = self.root / "output.wav"
        process = self.start("--verbose", "--output", str(output))
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, err)
        self.assertIn(b"diagnostic", err)
        self.assertEqual(output.read_bytes(), b"complete wave")

    def test_cancel_both_pipeline_groups_and_descendants(self):
        for stage in ("generation", "playback"):
            for sig in (signal.SIGINT, signal.SIGTERM):
                with self.subTest(stage=stage, signal=sig):
                    for name in ("engine", "player"):
                        (self.root / (name + ".pid")).unlink(missing_ok=True)
                        body = (
                            "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                            "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])\n"
                            f"(root / '{name}.pid').write_text(str(os.getpid()) + ' ' + str(child.pid))\n"
                        )
                        if name == "engine" and stage == "playback":
                            body += "os.write(1, b'abcd')\n"
                        elif name == "player" and stage == "playback":
                            body += (
                                "assert os.read(0, 4) == b'abcd'\n"
                                "(root / 'playing').touch()\ntime.sleep(60)\n"
                            )
                        else:
                            body += "time.sleep(60)\n"
                        self.script(name, body)
                    (self.root / "playing").unlink(missing_ok=True)
                    process = self.start()
                    self.wait_for(
                        lambda: all(
                            (self.root / (n + ".pid")).exists()
                            for n in ("engine", "player")
                        )
                    )
                    pids = [
                        int(pid)
                        for name in ("engine", "player")
                        for pid in (self.root / (name + ".pid")).read_text().split()
                    ]
                    if stage == "playback":
                        self.wait_for(lambda: (self.root / "playing").exists())
                    process.send_signal(sig)
                    _, err = process.communicate(timeout=5)
                    self.assertEqual(process.returncode, 130, err)
                    for pid in pids:
                        path = Path(f"/proc/{pid}/stat")
                        self.wait_for(
                            lambda: (
                                not path.exists()
                                or path.read_text().split(") ", 1)[1].startswith("Z")
                            )
                        )


if __name__ == "__main__":
    unittest.main()
