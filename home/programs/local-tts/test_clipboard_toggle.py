import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import clipboard_toggle


class ToggleTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.state = self.root / "state"
        self.log = self.root / "log"
        self.state.write_text("inactive")
        self.controller = self.root / "systemctl"
        self.controller.write_text(
            f"#!{sys.executable}\n"
            "import json, pathlib, sys, time\n"
            f"root = pathlib.Path({str(self.root)!r})\n"
            "args = sys.argv[1:]\n"
            "with (root / 'log').open('a') as log:\n"
            "    log.write(json.dumps(args) + '\\n')\n"
            "assert args[0] == '--user'\n"
            "action = args[1]\n"
            "if action != 'import-environment':\n"
            "    assert args[-1] == 'clipboard-speech.service'\n"
            "if (root / 'error').exists() and (root / 'error').read_text() == action:\n"
            "    sys.exit(1)\n"
            "if action == 'show':\n"
            "    print((root / 'state').read_text())\n"
            "elif action in ('start', 'stop'):\n"
            "    time.sleep(0.03)\n"
            "    (root / 'state').write_text(\n"
            "        'active' if action == 'start' else 'inactive')\n"
        )
        self.controller.chmod(0o700)

    def toggle(self):
        clipboard_toggle.toggle(self.root, str(self.controller))

    def actions(self):
        return [json.loads(line)[1] for line in self.log.read_text().splitlines()]

    def test_start_stop_and_restart(self):
        for state in ("active", "inactive", "active", "inactive"):
            self.toggle()
            self.assertEqual(self.state.read_text(), state)
        self.assertEqual(
            [action for action in self.actions() if action in ("start", "stop")],
            ["start", "stop", "start", "stop"],
        )

    def test_finished_and_failed_requests_can_restart(self):
        for state in ("inactive", "failed") * 4:
            self.state.write_text(state)
            self.toggle()
            self.assertEqual(self.state.read_text(), "active")

    def test_transitional_states_stop(self):
        for state in ("activating", "deactivating", "reloading"):
            self.state.write_text(state)
            self.toggle()
            self.assertEqual(self.state.read_text(), "inactive")

    def test_controller_error_releases_lock(self):
        for action, state in (
            ("show", "inactive"),
            ("start", "inactive"),
            ("stop", "active"),
        ):
            self.state.write_text(state)
            (self.root / "error").write_text(action)
            with self.assertRaises(subprocess.CalledProcessError):
                self.toggle()
            (self.root / "error").unlink()
            self.toggle()
            self.assertEqual(
                self.state.read_text(), "inactive" if state == "active" else "active"
            )

    def test_unknown_state_does_not_start(self):
        self.state.write_text("unknown")
        with self.assertRaises(ValueError):
            self.toggle()
        self.assertEqual(self.actions(), ["show"])

    def test_concurrent_presses_are_serialized(self):
        processes = []
        try:
            for _ in range(10):
                processes.append(
                    subprocess.Popen(
                        [
                            sys.executable,
                            str(Path(clipboard_toggle.__file__)),
                            str(self.controller),
                        ],
                        env={**os.environ, "XDG_RUNTIME_DIR": str(self.root)},
                    )
                )
            for process in processes:
                self.assertEqual(process.wait(timeout=15), 0)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                process.wait()
        self.assertEqual(self.state.read_text(), "inactive")
        self.assertEqual(
            [action for action in self.actions() if action in ("start", "stop")],
            ["start", "stop"] * 5,
        )

    def test_unrelated_playback_is_not_signalled(self):
        player = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        try:
            self.toggle()
            self.toggle()
            self.assertIsNone(player.poll())
        finally:
            player.terminate()
            player.wait()


if __name__ == "__main__":
    unittest.main()
