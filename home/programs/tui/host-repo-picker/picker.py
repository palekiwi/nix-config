import argparse
from dataclasses import dataclass
import fcntl
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tomllib


@dataclass(frozen=True)
class Repo:
    group: str
    name: str
    path: Path

    @property
    def identity(self):
        return f"{self.group}/{self.name}"


def load_repos(path):
    with open(path, "rb") as file:
        groups = tomllib.load(file)["groups"]
    if not isinstance(groups, dict):
        raise ValueError("groups must be a TOML table")
    repos = []
    for group, entries in groups.items():
        if not isinstance(entries, dict):
            raise ValueError(f"Group must contain repo paths: {group}")
        if (
            not group
            or any(c in group for c in ".:\n\r\t")
            or any(ord(c) < 32 or ord(c) == 127 for c in group)
        ):
            raise ValueError(f"Invalid group: {group}")
        for name, directory in entries.items():
            if not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
                raise ValueError(f"Invalid repo name: {name}")
            path = Path(directory).expanduser()
            if not path.is_absolute() or any(c in str(path) for c in "\n\r\t"):
                raise ValueError(f"Invalid repo path: {directory}")
            repos.append(Repo(group, name, path))
    if not repos:
        raise ValueError("No repositories configured")
    return repos


class Tmux:
    def __init__(self, command=None):
        self.command = command or ["tmux"]

    def run(self, *args):
        return subprocess.run(
            [*self.command, *args], check=True, capture_output=True, text=True
        ).stdout.rstrip("\n")

    def sessions(self):
        try:
            output = self.run("list-sessions", "-F", "#{session_name}\t#{session_id}")
        except subprocess.CalledProcessError as error:
            if any(
                s in error.stderr
                for s in ("no server running", "No such file", "error connecting")
            ):
                return {}
            raise
        return dict(line.split("\t", 1) for line in output.splitlines())

    def windows(self, session):
        return dict(
            (identity, window)
            for window, identity in (
                line.split("\t", 1)
                for line in self.run(
                    "list-windows",
                    "-t",
                    session,
                    "-F",
                    "#{window_id}\t#{@host-repo-id}",
                ).splitlines()
            )
            if identity
        )

    def open_repos(self):
        return {
            identity
            for session in self.sessions().values()
            for identity in self.windows(session)
        }

    def select(self, repo, client=None):
        sessions = self.sessions()
        if sessions:
            socket = self.run("display-message", "-p", "#{socket_path}")
        elif "-S" in self.command:
            socket = self.command[self.command.index("-S") + 1]
        else:
            socket = os.environ.get("TMUX", "").split(",")[0] or str(
                Path(os.environ.get("TMUX_TMPDIR", "/tmp"))
                / f"tmux-{os.getuid()}/default"
            )
        Path(socket).parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with open(socket + ".host-repo-picker.lock", "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if not repo.path.is_dir():
                raise ValueError(f"Directory does not exist: {repo.path}")
            session = self.sessions().get(repo.group)
            if session:
                marker = self.run(
                    "show-options", "-qv", "-t", session, "@host-repo-workspace"
                )
                identities = self.windows(session)
                if marker != "1" and not identities:
                    raise ValueError(
                        f"Unmanaged session collision: {repo.group}. "
                        "Rename the legacy session explicitly before using this workspace "
                        "(for original host palekiwi: tmux rename-session -t '=palekiwi' palekiwi-legacy)."
                    )
            window = self.windows(session).get(repo.identity) if session else None
            if window is None:
                shell = self.run(
                    "start-server", ";", "show-options", "-gv", "default-shell"
                )
                command = "exec " + shlex.quote(shell)
                if session:
                    window = self.run(
                        "new-window",
                        "-d",
                        "-P",
                        "-F",
                        "#{window_id}",
                        "-t",
                        session + ":",
                        "-n",
                        repo.name,
                        "-c",
                        str(repo.path),
                        command,
                    )
                else:
                    result = self.run(
                        "new-session",
                        "-d",
                        "-P",
                        "-F",
                        "#{session_id}\t#{window_id}",
                        "-s",
                        repo.group,
                        "-n",
                        repo.name,
                        "-c",
                        str(repo.path),
                        command,
                    )
                    session, window = result.split("\t")
                self.run("set-option", "-t", session, "@host-repo-workspace", "1")
                self.run(
                    "set-option", "-w", "-t", window, "@host-repo-id", repo.identity
                )
                self.run("set-option", "-w", "-t", window, "@host-repo-name", repo.name)
            self.run("select-window", "-t", window)
            if client is not None:
                self.run("switch-client", "-c", client, "-t", session)
            return window

    def desktop(self, repo):
        self.select(repo)
        session = self.sessions()[repo.group]
        clients = self.run(
            "list-clients", "-F", "#{session_id}\t#{client_pid}"
        ).splitlines()
        pids = set()
        for row in clients:
            attached, pid = row.split("\t")
            if attached != session:
                continue
            while pid not in pids and pid != "1":
                pids.add(pid)
                try:
                    stat = Path(f"/proc/{pid}/stat").read_text()
                    pid = stat.rsplit(")", 1)[1].split()[1]
                except (OSError, IndexError):
                    break
        windows = subprocess.run(
            ["wmctrl", "-lp"], check=True, capture_output=True, text=True
        ).stdout
        matches = []
        for row in windows.splitlines():
            fields = row.split(None, 4)
            if len(fields) >= 3 and fields[2] in pids:
                matches.append(fields[0])
        if len(matches) == 1:
            subprocess.run(["wmctrl", "-ia", matches[0]], check=True)
            return
        subprocess.Popen(
            [
                "kitty",
                "--title",
                repo.group,
                "-e",
                *self.command,
                "attach-session",
                "-t",
                session,
            ],
            start_new_session=True,
        )


def choose(repos, opened, desktop=False):
    rows = [
        f"{index}\t{repo.group}  {repo.name}"
        f"  {'[open]' if repo.identity in opened else ''}  {repo.path}"
        for index, repo in enumerate(repos)
    ]
    env = os.environ.copy()
    env.pop("FZF_DEFAULT_OPTS", None)
    env.pop("FZF_DEFAULT_OPTS_FILE", None)
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-no-custom", "-p", "Host repo"]
        if desktop
        else [
            "fzf",
            "--layout=reverse",
            "--no-multi",
            "--delimiter=\t",
            "--with-nth=2..",
            "--prompt=Host repo> ",
            "--header=All groups | Enter: open shell | Esc: cancel",
        ],
        input="\n".join(rows) + "\n",
        stdout=subprocess.PIPE,
        text=True,
        env=env,
    )
    if result.returncode in (1, 130):
        return None
    result.check_returncode()
    row = result.stdout.rstrip("\n")
    if row not in rows:
        raise ValueError("Unexpected picker selection")
    return repos[int(row.split("\t", 1)[0])]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        / "tmux/repos.toml",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--client")
    mode.add_argument("--desktop", action="store_true")
    args = parser.parse_args()
    tmux = Tmux()
    try:
        repos = load_repos(args.config)
        repo = choose(repos, tmux.open_repos(), desktop=args.desktop)
        if repo is not None:
            if args.desktop:
                tmux.desktop(repo)
            else:
                tmux.select(repo, args.client)
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.CalledProcessError,
    ) as error:
        message = f"Host repo picker: {error}"
        print(message, file=sys.stderr)
        if args.client:
            subprocess.run(
                ["tmux", "display-message", "-c", args.client, message], check=False
            )
        else:
            subprocess.run(["notify-send", "Host repo picker", message], check=False)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
