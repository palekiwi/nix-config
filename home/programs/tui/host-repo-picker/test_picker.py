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

from picker import Repo, Tmux, choose, format_rows, load_repos, main


REAL_RUN = subprocess.run


def picker_result(result):
    def run(command, **kwargs):
        if command[0] == "column":
            return REAL_RUN(command, **kwargs)
        return result

    return run


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
            "picker.subprocess.run",
            side_effect=picker_result(subprocess.CompletedProcess([], 1, "")),
        ) as run:
            self.assertIsNone(choose([repo], desktop=True))
        self.assertEqual(run.call_args.args[0][0:2], ["rofi", "-dmenu"])
        self.assertEqual(run.call_args.args[0][-1], "Palekiwi")
        self.assertIn("repo", run.call_args.kwargs["input"])

    def test_formatting_and_desktop_filter_identity(self):
        repos = [
            Repo("spabreaks", "one", Path.home() / "a space, ' quote"),
            Repo("palekiwi", "longer-name", Path("/tmp/two")),
        ]
        rows = format_rows(repos)
        self.assertIn("Spabreaks", rows[0])
        self.assertIn("~/a space, ' quote", rows[0])
        self.assertEqual(rows[0].index("one"), rows[1].index("longer-name"))
        result = subprocess.CompletedProcess([], 0, "0\n")
        with patch("picker.subprocess.run", side_effect=picker_result(result)) as run:
            self.assertEqual(choose(repos, desktop=True, group="palekiwi"), repos[1])
        self.assertEqual(run.call_args.args[0][-1], "Palekiwi")
        self.assertNotIn("one", run.call_args.kwargs["input"])
        self.assertNotIn("palekiwi", run.call_args.kwargs["input"])
        self.assertIn("longer-name", run.call_args.kwargs["input"])
        with self.assertRaisesRegex(ValueError, "Unknown workspace"):
            choose(repos, desktop=True, group="absent")

    def test_current_filter_and_unrelated_session(self):
        repos = [
            Repo("palekiwi", "one", Path("/tmp/one")),
            Repo("spabreaks", "two", Path("/tmp/two")),
        ]
        for current in ("palekiwi", "unrelated", None):
            result = subprocess.CompletedProcess([], 130, "")
            with patch(
                "picker.subprocess.run", side_effect=picker_result(result)
            ) as run:
                self.assertIsNone(choose(repos, current=current))
            command = run.call_args.args[0]
            rows = run.call_args.kwargs["input"]
            self.assertIn("one", rows)
            self.assertEqual("two" in rows, current != "palekiwi")
            self.assertEqual("--bind" in command, current == "palekiwi")
            self.assertFalse(any("Enter:" in arg or "Esc:" in arg for arg in command))
        with patch("picker.subprocess.run", side_effect=picker_result(result)) as run:
            choose(repos[:1], current="palekiwi")
        self.assertNotIn("--bind", run.call_args.args[0])
        self.assertIn("--prompt=Palekiwi> ", run.call_args.args[0])
        self.assertNotIn("Palekiwi", run.call_args.kwargs["input"])


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
            with patch("picker.subprocess.run", side_effect=picker_result(result)):
                self.assertIsNone(choose([repo]))
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
        self.assertNotIn("super + control + space; space", sxhkd)
        self.assertRegex(
            sxhkd,
            r"super \+ Return \+ control\n\s+.*host-repo-picker --desktop --group spabreaks",
        )
        self.assertRegex(
            sxhkd,
            r"super \+ Return \+ shift\n\s+.*host-repo-picker --desktop --group palekiwi",
        )
        self.assertRegex(
            sxhkd,
            r"super \+ Return\n\s+dmenu_remote_tmux agent-vm --prefix agent --tmux",
        )
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
            '[groups."host/spabreaks"]\npopup-repo = "'
            + str(repo.path)
            + '"\n[groups.other]\nother-repo = "/tmp"\n'
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
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.05)[0]:
                output += os.read(self.master, 65536)
            if b"host/spabreaks>" in output:
                break
        self.assertTrue(b"host/spabreaks>" in output, output[-1500:])
        for expected in (
            b"Ctrl-a: current workspace",
            b"Ctrl-a: all workspaces",
            b"Ctrl-a: current workspace",
        ):
            os.write(self.master, b"\x01")
            output = b""
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if select.select([self.master], [], [], 0.05)[0]:
                    output += os.read(self.master, 65536)
                if expected in output:
                    break
            self.assertIn(expected, output, output[-1500:])
        os.write(self.master, b"\x1b")
        time.sleep(0.3)
        self.assertEqual(before, self.snapshot())

    @unittest.skipUnless(
        os.environ.get("HOST_PICKER_TEST_CONFIG"), "build test-config.nix first"
    )
    def test_host_two_rows_and_vm_single_row(self):
        import pyte

        artifact = Path(os.environ["HOST_PICKER_TEST_CONFIG"])
        native = self.tmux.run("show-options", "-gv", "status-format[0]")
        self.tmux.run("source-file", str(artifact / "vm-tmux.conf"))
        self.assertEqual(self.tmux.run("show-options", "-gv", "status"), "on")
        self.assertIn(
            "#(_tmux_status-repo #{q:pane_current_path})",
            self.tmux.run("show-options", "-gv", "status-left"),
        )
        self.tmux.run("source-file", str(artifact / "tmux.conf"))
        self.assertEqual(self.tmux.run("show-options", "-gv", "status"), "2")
        self.assertEqual(
            self.tmux.run("show-options", "-gv", "status-format[0]"), native
        )
        self.assertNotIn("#(", self.tmux.run("show-options", "-gv", "status-left"))
        self.assertIn(
            "fg=colour208,bold",
            self.tmux.run("show-options", "-gv", "status-left"),
        )
        self.assertEqual(
            self.tmux.run("show-options", "-gv", "status-format[1]"),
            "#[align=left]#(_tmux_status-repo #{q:pane_current_path})",
        )
        for option in ("window-status-format", "window-status-current-format"):
            self.assertIn(
                "#{?@host-repo-name,#{@host-repo-name},#W}",
                self.tmux.run("show-options", "-gwv", option),
            )
        self.tmux.run(
            "set-environment",
            "-g",
            "PATH",
            f"{artifact / 'status/bin'}:{os.environ['PATH']}",
        )
        self.tmux.run("set-option", "-g", "status-interval", "1")
        repo = self.repo(group="palekiwi", name="active-repo")
        subprocess.run(
            ["git", "init", "-b", "branch-active", str(repo.path)],
            check=True,
            capture_output=True,
        )
        for key, value in (
            ("base", "main"),
            ("pr", "123"),
            ("cue-context", "scope/context"),
        ):
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(repo.path),
                    "config",
                    f"branch.branch-active.{key}",
                    value,
                ],
                check=True,
            )
        window = self.tmux.run(
            "new-window",
            "-P",
            "-F",
            "#{window_id}",
            "-c",
            str(repo.path),
            "-n",
            "unmanaged",
            "/bin/sh",
        )
        self.tmux.run(
            "set-option", "-w", "-t", window, "@host-repo-name", "managed-repo"
        )

        class StatusScreen(pyte.Screen):
            def report_device_status(self, mode, **kwargs):
                super().report_device_status(mode)

        screen = StatusScreen(100, 30)
        stream = pyte.Stream(screen)

        def wait_row(row, text):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                self.tmux.run("refresh-client", "-S", "-t", self.client)
                if select.select([self.master], [], [], 0.1)[0]:
                    stream.feed(os.read(self.master, 65536).decode(errors="replace"))
                if text in screen.display[row]:
                    return
            self.fail(f"Missing {text!r} in {screen.display[:2]!r}")

        wait_row(0, "managed-repo")
        wait_row(1, "branch-active")
        self.assertIn("scope/context", screen.display[1])
        self.assertIn("#123", screen.display[1])
        self.assertIn("main", screen.display[1])
        self.assertNotIn("branch-active", screen.display[0])
        navigation = screen.display[0]
        plain = self.root / "plain"
        plain.mkdir()
        self.tmux.run("split-window", "-v", "-c", str(plain), "/bin/sh")
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            self.tmux.run("refresh-client", "-S", "-t", self.client)
            if select.select([self.master], [], [], 0.1)[0]:
                stream.feed(os.read(self.master, 65536).decode(errors="replace"))
            if not screen.display[1].strip():
                break
        self.assertEqual(screen.display[0], navigation)
        self.assertFalse(screen.display[1].strip(), screen.display[1])

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
        self.assertEqual(cold.sessions(), {})
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
