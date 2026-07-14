# Project Log

## [4abc38d-dirty] Research complete: Multi-entry Copy for Telescope Pickers

- **Found:** Identified the core multi-copy logic in mem.lua
- **Found:** Mapped existing git and PR pickers in init.lua and gh-pr-picker.lua
- **Found:** Defined strategy for extracting helper function and updating mappings

## [381d551] Refactored copy_to_clipboard to shared telescope actions

## [6dea7d2] Enabled multi-copy for git commits

## [60876b0] Enabled multi-copy for GH PRs

## [b85ff01] Added MemLog Neovim utility

- **Found:** Implemented Markdown-to-JSON parser for log entries
- **Found:** Added transparent float UI using Snacks.win
- **Decided:** Mapped MemLog to <A-l> for ergonomic access
- **Decided:** Used --file JSON transport for mem log add safety

## [b7f33dc] Disabled line numbers in markdown files

- **Decided:** Disabled both absolute and relative line numbers for better readability in markdown files

## [7f3c72f-dirty] feat(mem): add context opening and picking commands

Added `M.open_context` and `M.pick_context` to `mem.lua` to support the new `mem context path` and `mem context path --all` commands. 
Registered `<A-c>` for opening the current context file and `<A-C>` for opening a Telescope picker with all context files in `mappings.lua`.
Added error notifications if the context file does not exist or if the command fails.

- **Found:** `mem` CLI now supports `context path` sub-command
- **Decided:** Implemented `mem context path` integration in Neovim
- **Decided:** Assigned `<A-c>` and `<A-C>` for context-related operations

## [b480d94-dirty] Support pagination in review comments

Implemented pagination for the 'review comments' function in gh-utils.nu. Added --paginate --slurp to the gh api call and used flatten to handle multiple pages of JSON results. This ensures that PRs with more than 30 review comments are fully fetched.

- **Found:** gh api defaults to 30 items per page without pagination flags
- **Decided:** Use --paginate --slurp for all collection-returning gh api calls
- **Decided:** Use flatten in Nushell to merge paginated results

## [e884a13-dirty] Support pagination in pr reviews

Updated 'pr reviews' function to support pagination for both the list of reviews and the nested comments within each review. Added --paginate --slurp and flatten to ensure all data is retrieved.

## [cb26e70-dirty] Support pagination in pr comments

Updated 'pr comments' function to support pagination for PR discussion (issue) comments. Added --paginate --slurp and flatten.

## [10e46ac-dirty] Support pagination in pr review comments

Updated 'pr review' function to support pagination for comments associated with a specific review. Added --paginate --slurp and flatten. Also unified the --full output to use the Nushell object converted to JSON for consistency.

## [0c4821a-dirty] Implement open_log in mem utils

Implemented M.open_log() in home/config/nvim/lua/config/utils/mem.lua to open the log file for the current git branch. Updated home/config/nvim/lua/config/mappings.lua to use this new function for the <A-l> mapping.

## [d382afe-dirty] Sanitize branch names in mem utils

Updated `get_current_branch()` in `home/config/nvim/lua/config/utils/mem.lua` to replace forward slashes (`/`) with hyphens (`-`) in branch names. This ensures consistency with how the `mem` CLI handles branch-based directory structures (e.g., `feat/my-feat` becomes `feat-my-feat`).

## [b35ae3d-dirty] Research complete: NixOS disk I/O investigation guide (host pale)

- **Found:** Host pale uses single ext4-on-LUKS root with no separate /nix/home/var — everything shares one device queue (hardware-configuration.nix:16-27)
- **Found:** Physical swap partition is on the same device (hardware-configuration.nix:29-31) — prime swap-thrash suspect
- **Found:** Weekly nix.gc configured (system.nix:5-9); no auto-optimise-store, no fstrim, no smartd
- **Found:** Docker enabled (modules/docker.nix:12-15); Ollama with CUDA and loadModels=[] so models get evicted/re-read (ollama.nix:3-7)
- **Found:** No ZFS/btrfs/restic/borg/postgres present
- **Found:** Triage recipe: pidstat -d + iostat -x + mpstat + vmstat + fatrace during a freeze; atop for historical replay

## [e120bb6-dirty] Add palekiwi tmux session keybindings under t prefix

Added three sxhkd keybindings for palekiwi-labs repos in home/programs/gui/sxhkd.nix:
- super + space; t; e -> cue
- super + space; t; i -> cast
- super + space; t; n -> cue-plugins

These share the existing `t` chord prefix (alongside `t; t` for taskwarrior) and reuse the generic switchToSession helper (no script changes needed). Committed as e120bb6.

- **Found:** switchToSession (sxhkd.nix:27-38) is fully generic: takes any session name, focuses via wmctrl or spawns kitty+sesh connect. No per-session glue needed.
- **Found:** cue and cue-plugins sessions share the same path ~/code/palekiwi-labs/cue (sesh.toml:177 and :182) but are distinct named tmux sessions, so separate keybindings are valid.
- **Found:** sxhkd chord matching is prefix-tree based on the full sequence, so reusing `n`/`e`/`i` as third-position keys under `t` does not collide with notes (`n`) or other first-position prefixes.
- **Decided:** Prefix `t` instead of the initially proposed `p`: on Colemak, `t` is the physical `f` key (left index home row) vs `p` being physical `r` (left index top-row stretch). Ergonomics favored over the cleaner mnemonic of a dedicated `p` prefix.
- **Decided:** Third-position keys mapped to Colemak right-hand home row (e=middle, i=ring, n=index) with cue on the strongest middle finger since it's the most active repo. Pinky `o` left free.
- **Decided:** cue-plugins bound on `n` rather than left to the picker, since there are spare comfortable keys.
- **Decided:** Excluded the palekiwi bindings from the existing `p`-free reasoning once `t` was chosen; `t; t` taskwarrior kept as-is since full sequences don't collide in sxhkd.
- **Open:** Could not run nix/home-manager build validation (nix* and home-manager* are denied by permission rules). Change is a pure data addition mirroring the existing taskwarrior line, so syntactic risk is negligible, but an actual switch/rebuild was not performed in this environment.

## [ead174c] haze: add claude-ping timer (commit ead174c)

Added a NixOS system service + timer on the haze host that periodically runs an opencode/cast command as user `pl`.

New file: hosts/haze/claude-ping.nix (imported from hosts/haze/default.nix).

Command (cast pinned to a specific revision):
  nix run github:palekiwi-labs/cast/6a8ecd686eef6612d995b680e0a185e0efb101d0#cast -- run opencode run "hi" --model anthropic/claude-haiku-4-5

Timer behavior, per user decisions:
  - OnCalendar = *-*-* 06:00:00 (daily 6am anchor, Asia/Taipei)
  - OnUnitInactiveSec = 5h 5m (chosen option B: interval measured since last run FINISHED, not started)
  - Persistent = true (catch up missed runs on next boot)
  - Resulting schedule approx: 06:00, 11:05-11:07, 16:10-16:14, 21:15-21:21, then next-day 6am re-anchors

Service config:
  - Type = oneshot, fire-and-forget (no Restart)
  - User = pl, Group = users, HOME resolves to /home/pl
  - WorkingDirectory = /home/pl/code/test, ensured via ExecStartPre = -mkdir -p
  - Environment: CAST_VOLUMES_NAMESPACE=cast, CAST_AGENT_VERSIONS__OPENCODE=1.17.11
  - after/wants network-online.target (nix run needs network)
  - Uses ${pkgs.nix}/bin/nix explicitly so flake 'nix run' is reachable regardless of interactive PATH

- **Decided:** Timer uses OnUnitInactiveSec (5h5m after run finishes) per user choice of option B
- **Decided:** Daily OnCalendar 6am re-anchor accepted with the resulting ~02:20 overnight gap skipped
- **Decided:** cast flake pinned to revision 6a8ecd686eef6612d995b680e0a185e0efb101d0 (not a flake.nix input)
- **Decided:** No sops secret for ANTHROPIC_API_KEY: app handles its own auth
- **Decided:** Fire-and-forget oneshot, no Restart; TimeoutStartSec left at default
- **Decided:** System-level service (User=pl) rather than NixOS systemd.user.*, since haze has no home-manager wired in
- **Open:** Cannot run nix in this sandbox: build/eval verification deferred to the user (they confirmed they will validate). Should run: nixos-rebuild build/switch --flake .#haze, then systemctl list-timers claude-ping.timer and systemctl start claude-ping.service to smoke-test
- **Open:** file not auto-formatted with nixfmt-rfc-style (nixfmt unavailable in container); formatting may need a pass in the repo devShell if it drifts

## [b14a818] haze/claude-ping: use plain nix via service path (commit b14a818)

Follow-up cleanup to commit ead174c. The script used the explicit store path `${pkgs.nix}/bin/nix`, which is redundant because `path = [ pkgs.nix ]` already places that store path's bin on the service PATH, and on NixOS /run/current-system/sw/bin/nix is present anyway.

Changed the script to call plain `nix`. Kept `path = [ pkgs.nix ]` so the nix dependency stays explicitly declared and the unit remains self-contained and testable.

- **Decided:** Keep path = [ pkgs.nix ] for an explicit, pinned nix dependency rather than relying solely on the system PATH

## [04ea52c] haze/claude-ping: one service per namespace (commit 04ea52c)

Rewrote hosts/haze/claude-ping.nix to generate a dedicated systemd service + timer per namespace via mkService/mkTimer + builtins.listToAttrs (map ...) over namespaces = [ "cast" "cast-sb" ].

Generated units:
  - claude-ping-cast.{service,timer}     (CAST_VOLUMES_NAMESPACE=cast,     WorkingDirectory=/home/pl/code/cast)
  - claude-ping-cast-sb.{service,timer}  (CAST_VOLUMES_NAMESPACE=cast-sb,  WorkingDirectory=/home/pl/code/cast-sb)

Each namespace runs independently: own env, own per-namespace working dir (ensured via ExecStartPre), own OnUnitInactiveSec=5h5m cadence, own journal stream. Both timers fire daily at 06:00 in parallel. Each differs only in CAST_VOLUMES_NAMESPACE and working dir.

Renames prior single claude-ping unit to claude-ping-cast. NixOS manages the declarative symlinks, so the old claude-ping units are removed on rebuild.

- **Decided:** Two services + two timers (not one) so the runs are independent in failure, logs, lifecycle, and per-unit OnUnitInactiveSec cadence
- **Decided:** Uniform naming claude-ping-<namespace>, renaming existing claude-ping to claude-ping-cast
- **Decided:** Per-namespace working dir /home/pl/code/<namespace> to avoid host-side file collisions (.opencode/, sessions); cast namespace isolation separates container storage
- **Decided:** Both timers fire at 06:00 in parallel; no stagger (user said parallel is acceptable)
- **Decided:** DRY generation via listToAttrs+map so future namespaces are one list entry

## [28859f4] haze/claude-ping: put docker on service PATH (commit 28859f4)

Fixed runtime failure on haze: claude-ping-cast.service failed at start with `failed to spawn docker ps ...: No such file or directory (os error 2)`.

Root cause: the service shells out to `docker` via cast, but system services get a minimal PATH that does NOT include /run/current-system/sw/bin. Only `path = [ pkgs.nix ]` was set, so `docker` was not resolvable.

Fix (hosts/haze/claude-ping.nix, mkService):
  - Added `config` to module args.
  - path now includes `config.virtualisation.docker.package` alongside pkgs.nix. Using the config reference (not hardcoded pkgs.docker_29) keeps the CLI version in sync with the daemon pinned in modules/docker.nix and avoids duplicating the pin.

No daemon-access change: pl is in the docker group (modules/docker.nix:8-10) and systemd applies supplementary groups via initgroups, so /var/run/docker.sock is reachable.

- **Found:** cast spawns `docker ps --filter name=^cast-nix-daemon$` - it manages its own container cast-nix-daemon via the host docker daemon
- **Found:** haze runs BOTH docker (docker_29) and podman; cast uses docker specifically
- **Found:** NixOS system services have a minimal PATH excluding /run/current-system/sw/bin - shelled-out binaries must be added via the path option
- **Decided:** Use config.virtualisation.docker.package instead of hardcoding pkgs.docker_29 to auto-track daemon version and avoid duplicating the pin
- **Decided:** Rely on pl's docker group + systemd initgroups for socket access; revisit only if a permission error appears

## [5270a68-dirty] Add relative file-path copy binding (<leader>yr)

Implemented the open todo `allow-copying-relative-file-path.md`.

Background: commit bf14efa had switched all four context_clipboard functions from relative (`:~:.`) to absolute (`:p`). The user now wants BOTH available, keeping absolute as the default and adding one new binding for the cwd-relative path.

Changes:
- `home/config/nvim/lua/config/utils/context_clipboard.lua:6-8`: `copy_file_path` gains an optional `relative` param. When truthy it uses fnamemodify `:.` (path relative to cwd, falls back to absolute if the file is outside cwd); otherwise the original `:p` absolute behavior. Backward compatible - existing single-arg callers see `nil` -> absolute.
- `home/config/nvim/lua/config/mappings.lua:206`: new `<leader>yr` binding in the "Copy to clipboard" (`<leader>y`) group, placed beside `<leader>yf` (absolute). "r" = relative.

Scope kept minimal: the other three clipboard functions (diagnostics, visual range) were NOT given a relative mode since the todo only referenced the plain file-path binding. No nvim-config test harness exists, so verification was by diff inspection.

- **Decided:** Key `<leader>yr` chosen for the new binding - free under the `<leader>y` group, intuitive (r=relative), matches the 3-key style of the GitHub bindings.
- **Decided:** Added `relative` as a 2nd positional boolean to stay consistent with the existing `include_cursor` boolean style rather than refactoring to an opts table.
- **Decided:** Kept scope to `copy_file_path` only; did not touch the diagnostic/visual-range functions.

## [f0e16aa] Commit f0e16aa: relative file-path copy binding

Committed the relative file-path copy binding on master as f0e16aa.

Commit: `feat(nvim): add relative file-path copy binding` (2 files changed, 7 insertions(+), 2 deletions(-)).
- mappings.lua: +<leader>yr binding
- context_clipboard.lua: +optional `relative` param on copy_file_path

Pre-commit checks: confirmed `.cue/` is gitignored; staged diff contained only the two intended source files. No nvim-config test/lint harness exists, but the user verified the binding works in their editor before requesting the commit.

- **Decided:** Conventional-commit type `feat` and scope `(nvim)` to match the prior commit `feat(nvim): expand copied file paths to absolute paths`.
- **Decided:** Imperative-mood summary under 50 chars; body explains the why (complement existing absolute bindings) and the how (fnamemodify `:.` vs `:p`).

## [63a0269] Notes created by file path instead of title

Implemented path-based note creation so the user controls subdirectory placement. Spans two commits across two repos.

nix-config (63a0269): `<space>nn` / `<space>nN` now call `cue_utils.add_with_path("note", ...)` instead of `add_with_title`. The prompt is a file path (with file completion), not a title.

cue.nvim plugin (d61133b): added `core.add_with_path(type, branch)` + re-export in `init.lua`. Mirrors `add_spec` but is type-parameterized and applies only the type's default frontmatter (no title). Always passes `--root`, so a typed path like `research/foo.md` lands at `.cue/<branch>/note/research/foo.md` and is the stable address.

Resulting invocation for `<space>nn`: `cue add research/foo.md --type note --root --branch master --frontmatter status=open`.

- **Found:** cue.nvim is loaded in dev mode via dir = ~/code/palekiwi-labs/cue.nvim (plugins/cue.lua:5), so plugin edits take effect on next Neovim restart without any nix rebuild
- **Found:** M.add() only iterates opts.frontmatter read-only (core.lua:156-161), so passing config.TYPE_DEFAULTS by reference is safe — no mutation
- **Found:** The existing add_spec (core.lua:247) already proves the path+root invocation shape against the cue CLI; add_with_path reuses it verbatim
- **Found:** No test harness (no busted/plenary) and luacheck is not installed in this environment; verification was by code reading + mirroring the proven add_spec pattern
- **Found:** git -C is denied by opencode permission rules; must use the workdir parameter instead for multi-repo git operations
- **Decided:** Scope: notes only (decision 1a) — todos/plans/tasks stay title-based since they are tracked board items
- **Decided:** Replace the existing note mappings rather than adding new ones (decision 2a) — the title flow for notes is gone
- **Decided:** Always pass --root so the typed path is the actual address (decision 3a) — subdirectory control only makes sense with root placement
- **Decided:** Omit title frontmatter entirely (decision 4a); notes get only status=open from TYPE_DEFAULTS
- **Decided:** Add a new generic add_with_path(type, branch) to the plugin rather than generalizing add_with_title or inlining in mappings.lua (decision 5a)

