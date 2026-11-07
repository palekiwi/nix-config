import os
from pathlib import Path
import pty
import subprocess
import struct
import select
import tempfile
import termios
import fcntl
import time
import unittest
from unittest.mock import patch

from picker import Repo, Tmux, choose, load_repos, main


class ConfigTests(unittest.TestCase):
    def test_shipped_config(self):
        config = Path(__file__).parents[3] / "config/tmux/repos.toml"
        with patch.dict(os.environ, {"HOME": "/tmp/picker-home"}):
            repos = load_repos(config)
        self.assertEqual(len(repos), 8)
        paths = {repo.identity: str(repo.path) for repo in repos}
        self.assertEqual(
            paths,
            {
                "palekiwi/nix-config": "/tmp/picker-home/nix-config",
                "palekiwi/palekiwi": "/tmp/picker-home/code/palekiwi/palekiwi",
                "palekiwi/cue": "/tmp/picker-home/code/palekiwi-labs/cue",
                "palekiwi/cue-platform": "/tmp/picker-home/code/palekiwi-labs/cue-platform",
                "palekiwi/config-cue": "/tmp/picker-home/.config/cue",
                "spabreaks/spabreaks": "/tmp/picker-home/code/spabreaks/spabreaks",
                "spabreaks/voucher-portal": "/tmp/picker-home/code/spabreaks/voucher-portal",
                "spabreaks/my-account": "/tmp/picker-home/code/spabreaks/my-account",
            },
        )

    def test_invalid_config(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "repos.toml"
            for content in (
                '[groups."bad:name"]\nrepo = "/tmp"',
                '[groups."bad.name"]\nrepo = "/tmp"',
                '[groups.""]\nrepo = "/tmp"',
                '[groups."host/test"]\nrepo = "relative"',
                '[groups."host/test"]\n"bad:name" = "/tmp"',
                "[groups]",
            ):
                config.write_text(content)
                with self.assertRaises(ValueError):
                    load_repos(config)

    def test_workspace_names_and_desktop_cancel(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "repos.toml"
            for group in (
                "palekiwi",
                "spabreaks",
                "a workspace",
                "team/project",
                "-team",
            ):
                config.write_text(f'[groups."{group}"]\nrepo = "/tmp"')
                self.assertEqual(load_repos(config)[0].group, group)
        repo = Repo("palekiwi", "repo", Path("/tmp"))
        with patch(
            "picker.subprocess.run", return_value=subprocess.CompletedProcess([], 1, "")
        ) as run:
            self.assertIsNone(choose([repo], set(), desktop=True))
        self.assertEqual(run.call_args.args[0][0:2], ["rofi", "-dmenu"])
        self.assertIn("palekiwi  repo", run.call_args.kwargs["input"])

    def test_picker_lists_all_groups_and_marks_open(self):
        repos = [
            Repo("host/a", "one", Path("/tmp/one")),
            Repo("host/b", "two", Path("/tmp/two")),
        ]
        result = subprocess.CompletedProcess([], 0, "1\thost/b  two    /tmp/two\n")
        with patch("picker.subprocess.run", return_value=result) as run:
            self.assertEqual(choose(repos, {"host/a/one"}), repos[1])
        rows = run.call_args.kwargs["input"]
        self.assertIn("host/a  one  [open]", rows)
        self.assertIn("host/b  two", rows)


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="repo-picker-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tmux = Tmux(["tmux", "-S", str(self.root / "socket")])
        self.tmux.run(
            "-f",
            "/dev/null",
            "new-session",
            "-d",
            "-s",
            "palekiwi",
            "-n",
            "legacy",
            "/bin/sh",
        )
        self.addCleanup(self.stop_server)
        self.tmux.run("set-option", "-g", "default-shell", "/bin/sh")
        self.tmux.run("set-option", "-g", "default-command", "exit 99")
        self.legacy = self.tmux.run(
            "list-panes",
            "-a",
            "-F",
            "#{session_id}:#{window_id}:#{pane_id}:#{pane_pid}",
        )
        master, slave = pty.openpty()
        self.master = master
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, slave)
        self.client_process = subprocess.Popen(
            [*self.tmux.command, "attach-session", "-t", "=palekiwi"],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env={**os.environ, "TERM": "xterm-256color"},
        )
        self.addCleanup(self.stop_client)
        for _ in range(100):
            self.client = self.tmux.run("list-clients", "-F", "#{client_name}")
            if self.client:
                break
            time.sleep(0.02)
        self.assertTrue(self.client, "isolated client did not attach")

    def stop_client(self):
        self.client_process.terminate()
        self.client_process.wait(timeout=5)

    def stop_server(self):
        subprocess.run([*self.tmux.command, "kill-server"], capture_output=True)

    def repo(self, group="host/palekiwi", name="repo"):
        path = self.root / f"{name} space ' quote ; $shell"
        path.mkdir(exist_ok=True)
        return Repo(group, name, path)

    def snapshot(self):
        return self.tmux.run(
            "list-windows", "-a", "-F", "#{session_name}:#{window_id}:#{@host-repo-id}"
        )

    def test_repeat_selection_preserves_pane_and_renamed_window(self):
        repo = self.repo()
        window = self.tmux.select(repo, self.client)
        self.assertEqual(
            self.tmux.run(
                "display-message", "-p", "-t", window, "#{pane_current_path}"
            ),
            str(repo.path),
        )
        pane = self.tmux.run("list-panes", "-t", window, "-F", "#{pane_id}:#{pane_pid}")
        self.tmux.run(
            "send-keys", "-t", window, "printf 'PRESERVED-CONTENT\\n'", "Enter"
        )
        self.tmux.run("rename-window", "-t", window, "user renamed")
        self.assertIn(repo.identity, self.tmux.open_repos())
        self.assertEqual(self.tmux.select(repo, self.client), window)
        self.assertEqual(
            self.tmux.run("list-panes", "-t", window, "-F", "#{pane_id}:#{pane_pid}"),
            pane,
        )
        for _ in range(100):
            capture = self.tmux.run("capture-pane", "-p", "-t", window)
            if "PRESERVED-CONTENT" in capture:
                break
            time.sleep(0.02)
        self.assertIn("PRESERVED-CONTENT", capture)
        self.assertEqual(len(self.tmux.windows(self.tmux.sessions()[repo.group])), 1)
        self.assertEqual(
            self.tmux.run(
                "list-panes",
                "-t",
                "=palekiwi",
                "-F",
                "#{session_id}:#{window_id}:#{pane_id}:#{pane_pid}",
            ),
            self.legacy,
        )

    def test_groups_same_names_unmanaged_window_and_client_switch(self):
        first = self.repo()
        window = self.tmux.select(first, self.client)
        session = self.tmux.sessions()[first.group]
        unmanaged = self.tmux.run(
            "new-window",
            "-d",
            "-P",
            "-F",
            "#{window_id}",
            "-t",
            session + ":",
            "-n",
            "another",
            "/bin/sh",
        )
        other = self.repo(name="another")
        managed = self.tmux.select(other, self.client)
        self.assertNotEqual(managed, unmanaged)
        second = self.repo(group="host/spabreaks")
        second_window = self.tmux.select(second, self.client)
        self.assertNotEqual(second_window, window)
        self.assertEqual(
            self.tmux.run("list-clients", "-F", "#{session_name}"), "host/spabreaks"
        )
        self.assertEqual(self.tmux.select(first, self.client), window)
        self.assertEqual(
            self.tmux.run("list-clients", "-F", "#{session_name}"), "host/palekiwi"
        )

    def test_missing_path_and_cancel_have_no_side_effects(self):
        before = self.snapshot()
        repo = Repo("host/missing", "missing", self.root / "absent")
        with self.assertRaisesRegex(ValueError, "Directory does not exist"):
            self.tmux.select(repo, self.client)
        self.assertEqual(before, self.snapshot())
        for code in (1, 130):
            result = subprocess.CompletedProcess([], code, "")
            with patch("picker.subprocess.run", return_value=result):
                self.assertIsNone(choose([repo], set()))
            self.assertEqual(before, self.snapshot())
        valid = self.repo()
        self.tmux.select(valid, self.client)
        before = self.snapshot()
        valid.path.rmdir()
        with self.assertRaises(ValueError):
            self.tmux.select(valid, self.client)
        self.assertEqual(before, self.snapshot())

    @unittest.skipUnless(
        os.environ.get("HOST_PICKER_TEST_CONFIG"), "build test-config.nix first"
    )
    def test_generated_bindings_and_real_popup(self):
        artifact = Path(os.environ["HOST_PICKER_TEST_CONFIG"])
        sxhkd = (artifact / "sxhkdrc").read_text()
        self.assertIn("super + control + space; space", sxhkd)
        self.assertIn("host-repo-picker --desktop", sxhkd)
        self.assertIn("switchToSession palekiwi-legacy", sxhkd)
        self.assertIn("switchToAgentSession palekiwi", sxhkd)
        host_sesh = (artifact / "sesh.toml").read_text()
        self.assertIn('name = "palekiwi-legacy"', host_sesh)
        self.assertNotIn('name = "palekiwi"', host_sesh)
        shared_sesh = (Path(__file__).parents[3] / "config/sesh/sesh.toml").read_text()
        self.assertIn('name = "palekiwi"', shared_sesh)
        self.tmux.run("source-file", str(artifact / "tmux.conf"))
        binding = self.tmux.run("list-keys", "-T", "root", "C-f")
        self.assertIn("host-repo-picker --client #{q:client_name}", binding)
        self.assertNotIn("old-picker", binding)
        self.assertIn("choose-tree -w", self.tmux.run("list-keys", "-T", "prefix", "w"))
        self.assertIn(
            "#I:", self.tmux.run("show-options", "-gwv", "window-status-format")
        )
        repo = self.repo(group="host/spabreaks", name="popup-repo")
        config_dir = self.root / "config"
        (config_dir / "tmux").mkdir(parents=True)
        (config_dir / "tmux/repos.toml").write_text(
            '[groups."host/spabreaks"]\npopup-repo = "' + str(repo.path) + '"\n'
        )
        self.tmux.run("set-environment", "-g", "XDG_CONFIG_HOME", str(config_dir))
        os.write(self.master, b"\x06")
        output = b""
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.05)[0]:
                output += os.read(self.master, 65536)
            if b"Host repo>" in output:
                break
        self.assertTrue(b"Host repo>" in output, output[-1500:])
        os.write(self.master, b"popup-repo\r")
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if self.tmux.run("list-clients", "-F", "#{session_name}") == repo.group:
                break
            if select.select([self.master], [], [], 0.05)[0]:
                output += os.read(self.master, 65536)
        self.assertIn(repo.group, self.tmux.sessions(), output.decode(errors="replace"))
        self.assertEqual(
            self.tmux.run("list-clients", "-F", "#{session_name}"), repo.group
        )
        session = self.tmux.sessions()[repo.group]
        window = self.tmux.windows(session)[repo.identity]
        self.assertEqual(
            self.tmux.run(
                "display-message", "-p", "-t", window, "#{pane_current_path}"
            ),
            str(repo.path),
        )
        before = self.snapshot()
        os.write(self.master, b"\x06")
        output = b""
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.05)[0]:
                output += os.read(self.master, 65536)
            if b"Host repo>" in output:
                break
        self.assertTrue(b"Host repo>" in output, output[-1500:])
        os.write(self.master, b"\x1b")
        time.sleep(0.3)
        self.assertEqual(before, self.snapshot())

    def test_legacy_collision_and_explicit_rename(self):
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Unmanaged session collision"):
            self.tmux.select(self.repo(group="palekiwi"), self.client)
        self.assertEqual(before, self.snapshot())
        self.tmux.run("rename-session", "-t", "=palekiwi", "palekiwi-legacy")
        repo = self.repo(group="palekiwi")
        window = self.tmux.select(repo, self.client)
        self.assertEqual(self.tmux.select(repo, self.client), window)
        self.assertEqual(len(self.tmux.windows(self.tmux.sessions()[repo.group])), 1)
        self.assertIn("palekiwi-legacy", self.tmux.sessions())

    def test_desktop_focus_verifies_client_pid_not_title(self):
        repo = self.repo(group="spabreaks")
        window = self.tmux.select(repo, self.client)
        pid = self.tmux.run("list-clients", "-F", "#{client_pid}")
        real_run = subprocess.run
        real_popen = subprocess.Popen
        calls = []

        def external(command, **kwargs):
            if command[0] == "wmctrl":
                calls.append(command)
                return subprocess.CompletedProcess(
                    command, 0, f"0x123 0 {pid} host unrelated-title\n"
                )
            return real_run(command, **kwargs)

        with (
            patch("picker.subprocess.run", side_effect=external),
            patch("picker.subprocess.Popen", side_effect=real_popen) as launch,
        ):
            self.tmux.desktop(repo)
            self.assertFalse(
                any(call.args[0][0] == "kitty" for call in launch.call_args_list)
            )
        self.assertEqual(calls[-1], ["wmctrl", "-ia", "0x123"])
        self.assertEqual(
            self.tmux.windows(self.tmux.sessions()[repo.group])[repo.identity], window
        )

    def test_desktop_opens_without_hijacking_unrelated_client(self):
        repo = self.repo(group="spabreaks")
        real_run = subprocess.run
        real_popen = subprocess.Popen
        launched = []

        def spawn(command, **kwargs):
            if command[0] == "kitty":
                launched.append(command)
                return None
            return real_popen(command, **kwargs)

        def external(command, **kwargs):
            if command[0] == "wmctrl":
                self.assertEqual(command, ["wmctrl", "-lp"])
                return subprocess.CompletedProcess(
                    command, 0, "0x999 0 999999 host spabreaks\n"
                )
            return real_run(command, **kwargs)

        with (
            patch("picker.subprocess.run", side_effect=external),
            patch("picker.subprocess.Popen", side_effect=spawn),
        ):
            self.tmux.desktop(repo)
        session = self.tmux.sessions()[repo.group]
        self.assertEqual(launched[0][-3:], ["attach-session", "-t", session])
        self.assertEqual(
            self.tmux.run("list-clients", "-F", "#{session_name}"), "palekiwi"
        )
        self.assertEqual(len(self.tmux.windows(session)), 1)

    def test_cold_server_no_bootstrap_window(self):
        cold = Tmux(["tmux", "-S", str(self.root / "cold-socket"), "-f", "/dev/null"])
        self.addCleanup(
            lambda: subprocess.run([*cold.command, "kill-server"], capture_output=True)
        )
        self.assertEqual(cold.open_repos(), set())
        config = self.root / "cold.toml"
        config.write_text('[groups.palekiwi]\nrepo = "/tmp"')
        real_run = subprocess.run

        def cancel(command, **kwargs):
            if command[0] == "rofi":
                return subprocess.CompletedProcess(command, 1, "")
            return real_run(command, **kwargs)

        with (
            patch("picker.Tmux", return_value=cold),
            patch("sys.argv", ["picker", "--desktop", "--config", str(config)]),
            patch("picker.subprocess.run", side_effect=cancel),
        ):
            self.assertEqual(main(), 0)
        self.assertFalse((self.root / "cold-socket").exists())
        self.assertEqual(cold.sessions(), {})
        repo = self.repo(group="fresh workspace")
        window = cold.select(repo)
        self.assertEqual(cold.select(repo), window)
        self.assertEqual(list(cold.sessions()), [repo.group])
        self.assertEqual(len(cold.windows(cold.sessions()[repo.group])), 1)

    def test_prefix_session_is_not_reused(self):
        self.tmux.run("new-session", "-d", "-s", "host/palekiwi-old", "/bin/sh")
        self.tmux.select(self.repo(), self.client)
        self.assertIn("host/palekiwi", self.tmux.sessions())
        self.assertIn("host/palekiwi-old", self.tmux.sessions())


if __name__ == "__main__":
    unittest.main()
