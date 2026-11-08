import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


CONFIG = Path(sys.argv.pop(1)).resolve()
SOURCE = Path(__file__).resolve().parent


class DesktopBindings(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}")
        self.env.pop("TMUX", None)
        self.env.pop("DISPLAY", None)
        self.env.update(
            TMUX_TMPDIR=str(self.root), HOME=str(self.root), SHELL="/bin/sh"
        )

    def mock(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def test_generated_bindings_and_awesome_conflicts(self):
        lines = (CONFIG / "sxhkdrc").read_text().splitlines()
        bindings = {
            line: lines[i + 1].strip()
            for i, line in enumerate(lines)
            if line and not line[0].isspace() and not line.startswith("#")
        }
        expected = {
            "super + Return": "/bin/tmux-scratch",
            "super + control + Return": "/bin/host-repo-picker --desktop --group spabreaks",
            "super + alt + Return": "/bin/host-repo-picker --desktop --group palekiwi",
            "super + shift + Return": "dmenu_remote_tmux agent-vm --prefix agent",
            "super + BackSpace": "dmenu_tmux --tmux",
            "super + control + BackSpace": "dmenu_remote_tmux agent-vm --prefix agent --tmux",
        }
        for key, command in expected.items():
            if command.startswith("/"):
                self.assertTrue(bindings[key].endswith(command), bindings[key])
            else:
                self.assertEqual(bindings[key], command)
        self.assertNotIn("super + space; space", bindings)
        awesome = SOURCE.parents[1] / "config" / "awesome"
        forbidden = {
            (frozenset(["MODKEY"]), "Return"),
            (frozenset(["MODKEY", '"Control"']), "Return"),
            (frozenset(["MODKEY", "ALTKEY"]), "Return"),
            (frozenset(["MODKEY", '"Shift"']), "Return"),
            (frozenset(["MODKEY"]), "BackSpace"),
            (frozenset(["MODKEY", '"Control"']), "BackSpace"),
        }
        for path in awesome.rglob("*.lua"):
            text = re.sub(r"--\[\[.*?\]\]", "", path.read_text(), flags=re.S)
            text = re.sub(r"--[^\n]*", "", text)
            for mods, key in re.findall(r'awful\.key\(\{([^}]+)\},\s*"([^"]+)"', text):
                self.assertNotIn(
                    (frozenset(m.strip() for m in mods.split(",")), key),
                    forbidden,
                    str(path),
                )
        tags = (awesome / "tags.lua").read_text()
        self.assertFalse(re.search(r'key\s*=\s*"(?:Return|BackSpace)"', tags))

    def test_scratch_exact_reuse_focus_and_persistence(self):
        tmux = shutil.which("tmux")
        self.assertIsNotNone(tmux)

        def run(*args):
            return subprocess.check_output(
                [tmux, *args], env=self.env, text=True
            ).strip()

        self.addCleanup(
            lambda: subprocess.run(
                [tmux, "kill-server"], env=self.env, capture_output=True
            )
        )
        run("-f", "/dev/null", "new-session", "-d", "-s", "scratch-other", "/bin/sh")
        run("set-option", "-g", "default-command", "exit 99")
        run("set-option", "-g", "destroy-unattached", "off")
        self.mock(
            "wmctrl", 'printf "%s\\n" "$@" > "$HOME/focus"; test -f "$HOME/focused"'
        )
        self.mock("kitty", 'printf "%s\\n" "$@" > "$HOME/kitty"')
        helper = SOURCE / "tmux-scratch.sh"
        packaged = (CONFIG / "scratch/bin/tmux-scratch").read_text()
        self.assertIn(helper.read_text().strip(), packaged)
        for _ in range(2):
            subprocess.run(
                ["bash", "-euo", "pipefail", str(helper)], env=self.env, check=True
            )
            self.assertEqual(
                run("list-windows", "-t", "=scratch", "-F", "#{window_panes}"), "1"
            )
        pane = run("display-message", "-p", "-t", "=scratch:", "#{pane_id}")
        self.assertEqual(
            run("display-message", "-p", "-t", pane, "#{pane_start_command}"), "/bin/sh"
        )
        self.assertEqual(
            (self.root / "kitty").read_text().splitlines(),
            ["-T", "scratch", "-e", "tmux", "attach-session", "-t", "=scratch"],
        )
        self.env["TERM"] = "xterm-256color"
        pid, fd = pty.fork()
        if pid == 0:
            os.execve(tmux, [tmux, "attach-session", "-t", "=scratch"], self.env)
        output = b""
        try:
            for _ in range(100):
                if select.select([fd], [], [], 0)[0]:
                    try:
                        output += os.read(fd, 65536)
                    except OSError:
                        break
                if (
                    run("list-clients", "-t", "=scratch", "-F", "#{session_name}")
                    == "scratch"
                ):
                    break
                time.sleep(0.02)
            else:
                self.fail(f"isolated terminal did not attach: {output!r}")
        finally:
            os.close(fd)
            os.waitpid(pid, 0)
        self.assertEqual(
            run("list-clients", "-t", "=scratch", "-F", "#{session_name}"), ""
        )
        (self.root / "kitty").unlink()
        (self.root / "focused").touch()
        subprocess.run(
            ["bash", "-euo", "pipefail", str(helper)], env=self.env, check=True
        )
        self.assertFalse((self.root / "kitty").exists())
        self.assertEqual(
            (self.root / "focus").read_text().splitlines(), ["-Fa", "scratch"]
        )
        self.assertEqual(
            run("list-sessions", "-F", "#{session_name}"), "scratch\nscratch-other"
        )
        self.assertEqual(
            run("display-message", "-p", "-t", "=scratch:", "#{pane_id}"), pane
        )

    def test_remote_sources(self):
        payload = json.dumps([dict(Name="cue", Src="tmux", Path="/tmp", Attached=0)])
        self.mock(
            "ssh", f'printf "%s\\n" "$@" > "$HOME/ssh"; printf \'%s\\n\' \'{payload}\''
        )
        self.mock("column", "exec cat")
        self.mock("rofi", "cat >/dev/null; printf 'cue tmux /tmp\\n'")
        self.mock("wmctrl", "exit 0")
        self.mock("notify-send", "exit 98")
        for flags, expected in [([], ["--tmux", "--config"]), (["--tmux"], ["--tmux"])]:
            subprocess.run(
                [
                    str(CONFIG / "remote/bin/dmenu_remote_tmux"),
                    "agent-vm",
                    "--prefix",
                    "agent",
                    *flags,
                ],
                env=self.env,
                check=True,
            )
            self.assertEqual(
                (self.root / "ssh").read_text().splitlines(),
                ["agent-vm", "sesh", "list", "--json", *expected],
            )


if __name__ == "__main__":
    unittest.main()
