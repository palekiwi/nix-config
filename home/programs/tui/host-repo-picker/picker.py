import argparse
from dataclasses import dataclass
import fcntl
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
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


def display_group(group):
    return {"spabreaks": "Spabreaks", "palekiwi": "Palekiwi"}.get(group, group)


def format_rows(repos, group=None):
    visible = [
        (index, repo)
        for index, repo in enumerate(repos)
        if group is None or repo.group == group
    ]
    fields = []
    for _, repo in visible:
        try:
            relative = repo.path.relative_to(Path.home())
            path = "~" if relative == Path(".") else "~/" + str(relative)
        except ValueError:
            path = str(repo.path)
        columns = [repo.name, path]
        if group is None:
            columns.insert(0, display_group(repo.group))
        fields.append("\t".join(columns))
    if not fields:
        return []
    formatted = subprocess.run(
        ["column", "-t", "-s", "\t"],
        input="\n".join(fields) + "\n",
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return [
        f"{index}\t{row}" for (index, _), row in zip(visible, formatted, strict=True)
    ]


def choose(repos, desktop=False, group=None):
    if group is not None and not any(repo.group == group for repo in repos):
        raise ValueError(f"Unknown workspace: {group}")
    groups = {repo.group for repo in repos}
    initial = group
    if initial is None and len(groups) == 1:
        initial = next(iter(groups))
    rows = format_rows(repos, initial)
    prompt = display_group(initial) if initial else "Host repo"
    env = os.environ.copy()
    env.pop("FZF_DEFAULT_OPTS", None)
    env.pop("FZF_DEFAULT_OPTS_FILE", None)
    with tempfile.TemporaryDirectory(prefix="host-repo-picker-", dir="/tmp"):
        command = ["rofi", "-dmenu", "-i", "-no-custom", "-format", "i", "-p", prompt]
        allowed = rows
        if not desktop:
            command = [
                "fzf",
                "--with-shell=bash -c",
                "--layout=reverse",
                "--no-multi",
                "--delimiter=\t",
                "--with-nth=2..",
                f"--prompt={prompt}> ",
            ]
        result = subprocess.run(
            command,
            input="\n".join(row.split("\t", 1)[1] for row in rows) + "\n"
            if desktop
            else "\n".join(rows) + "\n",
            stdout=subprocess.PIPE,
            text=True,
            env=env,
        )
    if result.returncode in (1, 130):
        return None
    result.check_returncode()
    row = result.stdout.rstrip("\n")
    if desktop:
        if not row.isdecimal() or int(row) >= len(rows):
            raise ValueError("Unexpected picker selection")
        row = rows[int(row)]
    if row not in allowed:
        raise ValueError("Unexpected picker selection")
    return repos[int(row.split("\t", 1)[0])]


def window_rows(tmux, session):
    fields = []
    windows = tmux.run("list-windows", "-t", session, "-F", "#{window_id}")
    for window in windows.splitlines():
        values = [
            tmux.run("display-message", "-p", "-t", f"{session}:{window}", fmt)
            for fmt in ("#{window_index}", "#{window_name}", "#{pane_current_path}")
        ]
        fields.append((window, "\t".join(" ".join(v.split()) for v in values)))
    formatted = subprocess.run(
        ["column", "-t", "-s", "\t"],
        input="\n".join(row for _, row in fields) + "\n",
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return [
        f"{window}\t{row}" for (window, _), row in zip(fields, formatted, strict=True)
    ]


def choose_session(tmux, repos, session, group):
    rows = window_rows(tmux, session)
    repo_rows = [
        f"repo:{repos[int(row.split(chr(9), 1)[0])].identity}\t{row.split(chr(9), 1)[1]}"
        for row in format_rows(repos, group)
    ]
    env = os.environ.copy()
    env.pop("FZF_DEFAULT_OPTS", None)
    env.pop("FZF_DEFAULT_OPTS_FILE", None)
    with tempfile.TemporaryDirectory(
        prefix="host-repo-picker-", dir="/tmp"
    ) as directory:
        root = Path(directory)
        command = [
            "fzf",
            "--with-shell=bash -c",
            "--layout=reverse",
            "--no-multi",
            "--delimiter=\t",
            "--with-nth=2..",
            f"--prompt=Windows: {group}> ",
        ]
        if repo_rows:
            (root / "repos").write_text("\n".join(repo_rows) + "\n")
            (root / "windows-prompt").write_text(f"Windows: {group}> ")
            (root / "repos-prompt").write_text(f"Repos: {group}> ")
            reload_windows = shlex.join(
                [
                    sys.executable,
                    str(Path(__file__).resolve()),
                    "--window-rows",
                    session,
                ]
            )
            to_windows = f"reload-sync({reload_windows})+transform-prompt(cat {root}/windows-prompt)+clear-query"
            to_repos = f"reload-sync(cat {root}/repos)+transform-prompt(cat {root}/repos-prompt)+clear-query"
            toggle = (
                f"if [ -f {root}/repos-active ]; then rm {root}/repos-active; "
                f"printf '%s\\n' {shlex.quote(to_windows)}; else touch {root}/repos-active; "
                f"printf '%s\\n' {shlex.quote(to_repos)}; fi"
            )
            command += [
                "--header=Ctrl-a: toggle",
                "--bind",
                "ctrl-a:transform:" + toggle,
            ]
        result = subprocess.run(
            command,
            input="\n".join(rows) + "\n",
            stdout=subprocess.PIPE,
            text=True,
            env=env,
        )
    if result.returncode in (1, 130):
        return None
    result.check_returncode()
    identity = result.stdout.rstrip("\n").split("\t", 1)[0]
    if identity.startswith("repo:"):
        for repo in repos:
            if repo.group == group and identity == f"repo:{repo.identity}":
                return repo
    elif re.fullmatch(r"@[0-9]+", identity):
        existing = tmux.run("list-windows", "-t", session, "-F", "#{window_id}")
        if identity in existing.splitlines():
            return identity
    raise ValueError("Unexpected picker selection")


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
    mode.add_argument("--window-rows")
    parser.add_argument("--session")
    parser.add_argument("--group")
    args = parser.parse_args()
    tmux = Tmux()
    try:
        if args.window_rows:
            print("\n".join(window_rows(tmux, args.window_rows)))
            return 0
        if args.group and not args.desktop:
            raise ValueError("--group requires --desktop")
        if args.desktop:
            repo = choose(load_repos(args.config), desktop=True, group=args.group)
            if repo is not None:
                tmux.desktop(repo)
        else:
            session = args.session or tmux.run(
                "display-message", "-p", "-c", args.client, "#{session_id}"
            )
            group = tmux.run("display-message", "-p", "-t", session, "#{session_name}")
            repos = load_repos(args.config) if args.config.exists() else []
            selected = choose_session(tmux, repos, session, group)
            if isinstance(selected, Repo):
                tmux.select(selected, args.client)
            elif selected is not None:
                tmux.run("select-window", "-t", f"{session}:{selected}")
                tmux.run(
                    "switch-client", "-c", args.client, "-t", f"{session}:{selected}"
                )
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
