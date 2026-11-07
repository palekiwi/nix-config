# Host repo picker

Host-only C-f initially lists repos in the calling tmux workspace. Ctrl-a
switches between that original workspace and all configured workspaces,
without restarting the popup. From an unrelated session it lists all repos
without a misleading current-workspace toggle. Search by repo or workspace,
use arrows/Ctrl-n/Ctrl-p to move, Enter to select, and Escape or Ctrl-c to
cancel. No open-state markers are shown.

A single-workspace view has a workspace prompt (Spabreaks or Palekiwi) and
two columns: repo and path. The all-workspaces view adds a workspace column.
Paths under home use `~`. Both frontends align TAB-separated fields using
Linux `column -t -s TAB`, so spaces and commas in paths stay intact.
Desktop selection uses rofi's row index; fzf carries a hidden stable index.
Neither backend parses padded display text for repo identity.

Edit `home/config/tmux/repos.toml`, deployed by Home Manager to
`~/.config/tmux/repos.toml`. Each table names a session, and each entry maps
one stable repo name to an absolute or `~/` directory:

```toml
[groups.palekiwi]
nix-config = "~/nix-config"
```

Workspace names are freely configurable tmux session names: nonempty,
without periods, colons or control characters. Spaces and slashes are fine;
there is no mandatory namespace. Repo keys allow letters, digits,
underscores and hyphens. Changing a
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

## Host two-row status

The host uses two status rows at the top. Row one keeps tmux's native
window list, current/alert styles, overflow scrolling and mouse ranges.
Its left segment is the orange hostname and session (capped at 40 cells
so long session names leave navigation space). Managed windows keep their
repository names; unmanaged windows use their normal names.

Row two runs the unchanged git/branch/PR/cue detail helper for the active
pane's quoted current directory, outside the window-list loop. It has the
full terminal width, independent of row one's left-length budget. Existing
per-field ellipses remain; tmux clips the rendered row at the terminal's
right edge without wrapping. A non-repository pane leaves this row blank.
The shared configuration and VM's single-row layout are unchanged.

## Binding order and deployment

**Super+Ctrl+Return** runs `host-repo-picker --desktop --group spabreaks`;
**Super+Shift+Return** runs `host-repo-picker --desktop --group palekiwi`.
Each desktop picker contains only that workspace's repos, with no toggle.
The redundant Super+Ctrl+Space, Space trial launcher is removed.
**Super+Return** still opens the VM launcher, unchanged.
Both host shortcuts use `rofi -dmenu` with the same config, formatting and
selection backend as C-f. They work without a running tmux server and create
only the selected repo shell, not a bootstrap window. Cancellation never
starts a server. Existing rofi monospace fonts are unchanged.

Desktop focus matches workspace tmux client PIDs and their process ancestors
to `wmctrl -lp`, never a title alone. Exactly one matching X window is
focused by ID; otherwise a new kitty attaches to the exact session ID.
Ambiguous multi-window terminal PIDs deliberately open another terminal
rather than risk focusing an unrelated window. Existing unrelated clients
are never switched. This desktop path requires X11/wmctrl; those tools,
rofi, kitty and notifications are packaged dependencies.

Host Home Manager generates a `palekiwi-legacy` sesh entry from the shared
source; the VM continues reading the unchanged original `palekiwi` entry.
The old host Super+Ctrl+Space, t, n chord now opens `palekiwi-legacy`.
Other chord-layer bindings remain unchanged. Host extraConfig
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

Activate the resulting path with `/nix/store/...-home-manager-generation/activate`
(use the exact path printed by home-build). Then reload sxhkd and host tmux:

```sh
pkill -USR1 -x sxhkd
```

Before using either picker, migrate the original host session as described
below. Then explicitly reload the host tmux configuration when ready:

```sh
tmux source-file ~/.config/tmux/tmux.conf
tmux list-keys -T root C-f
tmux list-keys -T prefix w
```

Do not run those tmux commands through the agent VM's connection. No live
activation or reload is performed by the automated tests.

## Explicit host-only migration before first launch

Run these commands in a **host terminal**, not through agent-vm. Inspect
first, confirming `palekiwi` is the original legacy multi-window session
and `palekiwi-legacy` does not already exist:

```sh
tmux list-sessions
tmux list-windows -t '=palekiwi' -F '#{window_id} #{window_name} #{@host-repo-id}'
tmux rename-session -t '=palekiwi' palekiwi-legacy
```

Do not rename an already managed `palekiwi` workspace. The picker refuses
an existing untagged session instead of silently adding repos to it. It
never automatically renames any session. Renaming preserves windows and
processes. No live host migration is performed from the VM.

If trial `host/palekiwi` or `host/spabreaks` sessions exist, either leave
them alone (the new names create separate workspaces), or explicitly migrate
them after freeing the destination name. To preserve their tagged processes,
run this in a POSIX host shell, only for the trial sessions you inspected:

```sh
for group in palekiwi spabreaks; do
  if tmux has-session -t "=host/$group" 2>/dev/null; then
    tmux rename-session -t "=host/$group" "$group" || break
    tmux list-windows -t "=$group" -F '#{window_id}' |
      while read -r window; do
        identity=$(tmux show-options -wqv -t "$window" @host-repo-id)
        case "$identity" in
          host/*) tmux set-option -w -t "$window" @host-repo-id "${identity#host/}" ;;
        esac
      done
    tmux set-option -t "=$group" @host-repo-workspace 1
  fi
done
```

Do not use this loop for unrelated sessions. The destination must be absent;
if rename fails, stop and inspect instead of killing or merging sessions.

## Validation

From the nix-config root, enter the project devshell plus test dependencies:

```sh
nix develop --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in p.mkShell {
    inputsFrom = [ f.devShells.x86_64-linux.default ];
    packages = [
      (p.python3.withPackages (ps: [ ps.pyte ]))
      p.ruff p.tmux p.fzf p.util-linux p.git
    ];
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
  home/programs/tui/host-repo-picker/*.nix \
  home/programs/tui/sesh.nix home/programs/gui/sxhkd.nix
HOST_PICKER_TEST_CONFIG="$artifact" PYTHONDONTWRITEBYTECODE=1 \
  python3 -m unittest discover -s home/programs/tui/host-repo-picker -v
```

Tests use unique temporary sockets, real attached PTY clients, and cleanup.
They never connect to the default server. The generated-config test opens
C-f's actual packaged popup, selects a repo and cancels another popup. If
`HOST_PICKER_TEST_CONFIG` is omitted, that one test is skipped. This build
validates the picker and generated host tmux, sxhkd and sesh configuration,
not a full host activation. The status test also sources the real VM
module's generated extraConfig on its isolated server, checks one versus
two rows and the unchanged native first-row format, and renders the host
status through a PTY with an active Git pane and a non-Git split.
Desktop external tools are mocked; real X11
focus and fresh-boot keyboard behavior still require operator QA.

## Operator QA after deployment

- Confirm two host rows: orange hostname/session plus repo windows on row
  one; existing cue, branch, PR and base content on row two. Switch panes
  between repositories and non-Git directories; only row two should change.
- With a long branch/context and many repo windows, narrow and widen the
  terminal: details clip on row two without moving navigation. Select an
  offscreen window and verify native overflow markers/current visibility;
  click visible repo labels and verify native window selection.
- In the VM, confirm the original single-row status remains unchanged.

- C-f in Palekiwi/Spabreaks starts with only that workspace's repos.
  Ctrl-a shows all eight repos and toggles back to the original workspace.
  Only the compact Ctrl-a hint appears; no Enter/Escape help or open marker.
- C-f in an unrelated session starts with all repos and has no toggle hint.
- From a fresh boot, Super+Ctrl+Return lists only Spabreaks repos;
  Super+Shift+Return lists only Palekiwi repos. Check aligned repo/path
  columns, workspace prompts and abbreviated home paths. Escape creates no
  terminal/session. Super+Return still opens the VM launcher.
- Select a repo: correct plain-named session, correct directory, plain shell.
- Reselect from desktop: focus its verified terminal or attach a new kitty,
  preserving its repo process and leaving unrelated terminals untouched.
- Run something, switch groups, then reselect: the same process survives.
- Rename a managed window: reselect still finds it, status shows index/repo.
- Escape/Ctrl-c leaves the session/window set unchanged.
- An unavailable repo reports its missing path without a broken session.
- Prefix-w opens native window tree; the original host workflow remains
  available as `palekiwi-legacy`. VM `palekiwi` and bindings are unchanged.
