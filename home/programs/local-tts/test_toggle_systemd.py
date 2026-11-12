import json
import os
import shutil
import subprocess
import sys
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

import clipboard_toggle
import speak
import test_http


@unittest.skipUnless(os.environ.get("SPEAK_TEST_SYSTEMD"), "requires user systemd")
class SystemdToggleTests(unittest.TestCase):
    script = test_http.HTTPTests.script
    wait_for = test_http.HTTPTests.wait_for

    def setUp(self):
        test_http.HTTPTests.setUp(self)
        self.unit = f"clipboard-speech-test-{uuid.uuid4().hex}.service"
        self.runtime = Path(os.environ["XDG_RUNTIME_DIR"])
        self.systemctl = shutil.which("systemctl")
        self.env.update(
            DISPLAY=":clipboard-test",
            SPEAK_XCLIP=str(self.script("clipboard", "print('private input')\n")),
        )
        self.env.pop("WAYLAND_DISPLAY", None)
        unit_path = self.runtime / "systemd/user" / self.unit
        unit_path.parent.mkdir(parents=True, exist_ok=True)
        unit_path.write_text(
            "[Unit]\nStartLimitIntervalSec=0\n[Service]\nType=exec\n"
            "KillMode=control-group\nTimeoutStopSec=2s\nRestart=no\nSuccessExitStatus=130\n"
            + "".join(
                f"Environment={json.dumps(key + '=' + value)}\n"
                for key, value in self.env.items()
                if key.startswith("SPEAK_") or key in {"TEST_ROOT", "DISPLAY"}
            )
            + "UnsetEnvironment=WAYLAND_DISPLAY\n"
            + f"ExecStart={sys.executable} {speak.__file__} --clipboard\n"
        )
        self.addCleanup(self.cleanup_unit, unit_path)
        self.control("daemon-reload")
        self.addCleanup(patch.stopall)
        patch.object(clipboard_toggle, "UNIT", self.unit).start()

    def control(self, *args):
        return subprocess.run(
            [self.systemctl, "--user", *args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def cleanup_unit(self, path):
        self.control("stop", self.unit)
        subprocess.run(
            [self.systemctl, "--user", "reset-failed", self.unit], capture_output=True
        )
        path.unlink()
        self.control("daemon-reload")

    def state(self):
        return self.control("show", "--property=ActiveState", "--value", self.unit)

    def toggle(self):
        clipboard_toggle.toggle(self.root, self.systemctl)

    def test_stop_disconnects_http_kills_player_and_leaves_independent_process(self):
        self.mode = "cancel"
        self.script(
            "player",
            "(root / 'player.pid').write_text(str(os.getpid()))\n"
            "assert os.read(0, 4) == b'abcd'\n"
            "(root / 'received').touch()\n"
            "time.sleep(60)\n",
        )
        independent = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"]
        )
        try:
            self.toggle()
            self.wait_for(lambda: (self.root / "received").exists())
            pid = int((self.root / "player.pid").read_text())
            self.toggle()
            self.assertEqual(self.state(), "inactive")
            self.assertTrue(self.disconnected.wait(5))
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)
            self.assertIsNone(independent.poll())
        finally:
            independent.terminate()
            independent.wait()

    def test_finish_and_repeated_failures_reset_idle(self):
        self.mode = "complete"
        self.script("player", "sys.stdin.buffer.read()\n")
        self.toggle()
        self.wait_for(lambda: self.state() == "inactive")
        self.mode = "error"
        for _ in range(8):
            self.toggle()
            self.wait_for(lambda: self.state() == "failed")
            self.assertNotEqual(
                self.control("show", "--property=Result", "--value", self.unit),
                "start-limit-hit",
            )
        self.script("clipboard", "print('')\n")
        self.toggle()
        self.wait_for(lambda: self.state() == "failed")
        self.script("clipboard", "print('private input')\n")
        self.mode = "complete"
        self.toggle()
        self.wait_for(lambda: self.state() == "inactive")
