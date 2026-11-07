# Host repo picker

Host-only C-f opens all configured repos in one searchable list. Search by
repo or group, use arrows/Ctrl-n/Ctrl-p to move, Enter to select, and Escape
or Ctrl-c to cancel. There is no current-group filter. `[open]` means a
managed repo window exists.

Edit `home/config/tmux/repos.toml`, deployed by Home Manager to
`~/.config/tmux/repos.toml`. Each table names a session, and each entry maps
one stable repo name to an absolute or `~/` directory:

```toml
[groups."host/palekiwi"]
nix-config = "~/nix-config"
```

Group names must be `host/` followed by letters, digits, underscores or
hyphens. Repo names allow the same characters without a slash. Changing a
repo name changes its identity; changing its path only affects new windows.
The picker reads TOML at runtime with Nix-provided Python. `--config PATH`
can select an alternate file when invoking the CLI manually.

A selected repo reuses its `@host-repo-id` window in the exact group session,
even if that window was renamed. Otherwise it creates one plain shell using
tmux's configured default shell and the repo directory. It ignores
`default-command`, never sends startup keys, and never adopts a window just
because its name matches. `@host-repo-name` supplies the status label, with
`#W` as the fallback for unmanaged windows. Missing directories report a
tmux message without creating a session/window.

Selection uses session/window IDs and a per-server file lock next to the
tmux socket. The lock file can persist, but its lock is released on process
exit. No windows or sessions are created on picker cancellation.

## Binding order and deployment

Only `home/programs/tui/tmux.nix` imports this package. The shared module,
VM, sesh configuration and desktop chords are unchanged. Host extraConfig
uses `mkAfter` so C-f and prefix-w override earlier normal definitions.
Home Manager loads plugins before extraConfig. `run-shell` expands the
calling client before launching the popup; popup shell commands do not
expand tmux formats themselves. The popup and picker both target that client.
A later manually sourced configuration can still override these bindings.

On the host, fetch/fast-forward the nix-config change from the VM using the
existing workflow. Deploy the **Home Manager** configuration, not a NixOS or
VM rebuild. For the pale host, the existing Taskfile build is:

```sh
cd ~/nix-config
nix develop --command task home-build HOST=pale
```

Activate through the usual host Home Manager workflow (the Taskfile only
builds), then explicitly reload the host tmux configuration when ready:

```sh
tmux source-file ~/.config/tmux/tmux.conf
tmux list-keys -T root C-f
tmux list-keys -T prefix w
```

Do not run those tmux commands through the agent VM's connection. No live
activation or reload is performed by the automated tests.

## Validation

From the nix-config root, enter the project devshell plus test dependencies:

```sh
nix develop --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in p.mkShell {
    inputsFrom = [ f.devShells.x86_64-linux.default ];
    packages = [ p.python3 p.ruff p.tmux ];
  }
'
```

Then build the picker and a minimal Home Manager configuration using the
real host module, including deliberately conflicting earlier bindings:

```sh
artifact=$(nix build --impure --no-link --print-out-paths --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./home/programs/tui/host-repo-picker/test-config.nix {
    pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
    home-manager = f.inputs.home-manager;
  }
')
ruff check home/programs/tui/host-repo-picker
ruff format --check home/programs/tui/host-repo-picker
nixfmt --check home/programs/tui/tmux.nix \
  home/programs/tui/host-repo-picker/*.nix
HOST_PICKER_TEST_CONFIG="$artifact" PYTHONDONTWRITEBYTECODE=1 \
  python3 -m unittest discover -s home/programs/tui/host-repo-picker -v
```

Tests use unique temporary sockets, real attached PTY clients, and cleanup.
They never connect to the default server. The generated-config test opens
C-f's actual packaged popup, selects a repo and cancels another popup. If
`HOST_PICKER_TEST_CONFIG` is omitted, that one test is skipped. This build
validates the picker and host tmux configuration, not a full host activation.

## Operator QA after deployment

- C-f lists all eight repos across both groups, including unopened repos.
- Select a repo: correct `host/...` session, correct directory, plain shell.
- Run something, switch groups, then reselect: the same process survives.
- Rename a managed window: reselect still finds it, status shows index/repo.
- Escape/Ctrl-c leaves the session/window set unchanged.
- An unavailable repo reports its missing path without a broken session.
- Prefix-w opens native window tree; old `palekiwi`, sesh entries and chords
  still behave as before. VM bindings/layout are unchanged.
