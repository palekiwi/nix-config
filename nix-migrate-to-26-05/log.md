# Project Log

## [b05cd86] Phase 1: nvim treesitter migrated for 0.12 compatibility

Rewrote treesitter.lua to use the nvim-treesitter main branch API. Deleted treesitter-text-objects.lua and dropped nvim-treesitter-refactor (both unused).

- **Found:** tree-sitter CLI already present in dev.nix:17, no change to nvim.nix needed
- **Found:** render-markdown.lua declares nvim-treesitter as a lazy dep — no conflict since treesitter stays in lazy.nvim
- **Found:** Reference Nix-managed nvim implementation at /home/pl/.config/cast/nix/nvim.nix using nvf framework
- **Decided:** Keep nvim-treesitter in lazy.nvim (main branch) for now rather than switching to Nix-managed parsers — deferred to future neovim wrapper module refactor
- **Decided:** Use FileType autocmd + vim.treesitter.start for highlighting instead of the old setup() highlight module
- **Decided:** Use install API with get_installed() diff to avoid reinstalling parsers on every startup

## [265db6b] Phase 2: both flakes bumped to nixos-26.05

Updated nixpkgs and home-manager pins in both flake.nix and home/flake.nix. No changes needed for sops-nix, claude-desktop, or notifications-server (all follow nixpkgs).

- **Decided:** Bump both flakes in the same commit since they are independent changes with no ordering constraint at the code level — ordering only matters at switch time (home-manager before nixos-rebuild)

## [6e2e5ac] Fix: nodePackages removed in nixpkgs 26.05

home-manager switch failed because nodePackages has been removed in nixpkgs 26.05. Fixed by moving prettier and typescript-language-server to the top-level pkgs namespace in dev.nix.

- **Found:** nodePackages removed entirely in nixpkgs 26.05 - packages now at top level
- **Found:** Only two references existed, both in home/programs/tui/dev.nix
- **Found:** Several non-blocking deprecation warnings also present: withRuby/withPython3 neovim defaults, gtk.gtk4.theme, firefox.configPath, ssh.matchBlocks - all gated behind stateVersion < 26.05

## [79d6dd3] Fix: ollama acceleration option removed in nixpkgs 26.05

nixos-rebuild for pale failed because services.ollama.acceleration was removed. Migrated to package = pkgs.ollama-cuda. Also fixed module signature from { ... } to { pkgs, ... }.

- **Found:** services.ollama.acceleration removed in 26.05 - GPU variant now selected via services.ollama.package (ollama-cuda, ollama-rocm, ollama-vulkan, ollama-cpu, ollama)

## [bd0a52e] Deprecation fixes: xorg renames + home-manager option defaults

Fixed all mechanical deprecation warnings from the 26.05 migration. Two commits: xorg package renames across 3 files, and home-manager option defaults for neovim, gtk, and firefox.

- **Decided:** withRuby=false, withPython3=false: accepted new defaults — entire plugin stack is Lua, no remote providers needed
- **Decided:** gtk4.theme explicit: user wants Breeze-Dark everywhere, null default would leave GTK4 apps unstyled
- **Decided:** firefox.configPath pinned to legacy .mozilla/firefox: migrating to XDG requires moving the directory on disk, deferred to a separate task
- **Decided:** ssh.matchBlocks migration skipped: format of programs.ssh.settings not confirmed, non-blocking, needs research

## [9d3040d-dirty] [9d3040d] Fix: ssh matchBlocks migrated to settings API

Migrated programs.ssh.matchBlocks to programs.ssh.settings in home/programs/tui/ssh.nix. Directive names changed from lowercase nix-style (hostname, user, port) to canonical SSH casing (HostName, User, Port). Dropped the empty Host * placeholder block (was a no-op with only comments). Verified via nix eval that the deprecation warning is gone and the generated ~/.ssh/config is functionally identical.

- **Found:** programs.ssh.settings uses dagOf with freeformType types.attrsOf types.anything -- integers like Port = 438 are accepted directly, renderer does toString for non-booleans
- **Found:** Attribute name IS the Host pattern: bare keys get 'Host ' prepended by blockHeader(); keys starting with 'Host ' or 'Match ' are used literally
- **Found:** No DAG ordering (lib.hm.dag.entryBefore/entryAfter) needed when host patterns don't overlap -- plain attrsets suffice
- **Found:** enableDefaultConfig = false already set, which silences the separate enableDefaultConfig deprecation warning independently
- **Decided:** Dropped empty Host * block entirely instead of keeping it as settings."*" = {}; -- it generated a bare 'Host *' header with no directives, functionally a no-op
- **Decided:** Kept enableDefaultConfig = false rather than migrating to explicit settings."*" with default values -- that is a separate future concern, the enableDefaultConfig option is not yet removed
- **Open:** enableDefaultConfig option will be deprecated in the future -- at that point, manually set programs.ssh.settings."*" with desired defaults (ForwardAgent, AddKeysToAgent, Compression, etc.) per the home-manager docs

## [9d3040d] nvim 0.12 migration: nvim-treesitter.ts_utils broken in ftplugins

After migrating nvim-treesitter from `master` branch to `main` branch (treesitter.lua:4) for nvim 0.12 compatibility, two ftplugin files and settings.lua were not updated. The `main` branch removed `nvim-treesitter.ts_utils` module and the `nvim_treesitter#foldexpr()` VimL autoload function.

Error: `module 'nvim-treesitter.ts_utils' not found` at ftplugin/markdown/init.lua:1, triggered when cue.nvim opens a markdown buffer (core.lua:198 -> nvim_cmd -> filetype.lua -> ftplugin).

Affected files:
1. home/config/nvim/ftplugin/markdown/init.lua:1 — require("nvim-treesitter.ts_utils"), uses ts_utils.goto_node at lines 51, 76
2. home/config/nvim/ftplugin/ruby/init.lua:6 — same require, uses ts_utils.goto_node at lines 65, 90
3. home/config/nvim/lua/config/settings.lua:44 — foldexpr = "nvim_treesitter#foldexpr()" (currently no-op since foldmethod="indent", but should be fixed)
4. home/config/nvim/ftplugin/markdown/init.lua:86 — foldexpr = "nvim_treesitter#foldexpr()" (active, foldmethod="expr")
5. home/config/nvim/ftplugin/ruby/init.lua:97 — foldexpr = "nvim_treesitter#foldexpr()" (active, foldmethod="expr")

- **Found:** nvim-treesitter main branch removed nvim-treesitter.ts_utils module — the old master branch API is gone
- **Found:** nvim-treesitter main branch removed nvim_treesitter#foldexpr() VimL autoload function
- **Found:** ts_utils.goto_node(node) only moves cursor to node start — replaceable with vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
- **Found:** settings.lua:44 foldexpr is currently a no-op because foldmethod is 'indent' (line 43), but ftplugin foldexpr values ARE active because they set foldmethod='expr'
- **Found:** Migration log [b05cd86] confirms treesitter.lua was rewritten for main branch but ftplugins were missed
- **Found:** cue.nvim core.lua:198 is just the trigger (opens a file via nvim_cmd), not the root cause
- **Decided:** Replacement for ts_utils.goto_node: local function goto_node(node) local sr, sc = node:range() vim.api.nvim_win_set_cursor(0, { sr + 1, sc }) end — node:range() returns 0-indexed, nvim_win_set_cursor expects 1-indexed row + 0-indexed col
- **Decided:** Replacement for nvim_treesitter#foldexpr(): v:lua.vim.treesitter.foldexpr() — built-in Neovim function since 0.9, recommended with nvim-treesitter main branch
- **Open:** User has not yet confirmed whether to apply the fix

## [d97efcf] Fix: nushell trailing-slash PWD error on sesh session start

After the nixos-26.05 migration bumped nushell to 0.112.2, starting sesh-defined tmux sessions errored with `nu::shell::error: $env.PWD contains trailing slashes`. The error originated in nu-protocol/src/engine/engine_state.rs:983. Root cause: sesh passes the configured `path` from sesh.toml verbatim into the spawned shell's PWD env var, preserving trailing slashes; newer nushell rejects those. Fix: removed the trailing slash from all 22 affected paths in home/config/sesh/sesh.toml. The sessions already written without a trailing slash (dotfiles, nix-config, palekiwi paths, etc.) were unaffected and serve as the now-uniform style. Committed as d97efcf on nix/migrate-to-26-05.

- **Found:** nushell 0.112.2 (nixos-26.05) added a hard validation rejecting $env.PWD with trailing slashes, in nu-protocol/src/engine/engine_state.rs:983
- **Found:** sesh passes the sesh.toml `path` value verbatim into the spawned shell PWD (trailing slash preserved) -- confirmed by the error showing $env.PWD = /home/pl/.config/opencode/ matching sesh.toml:153 exactly
- **Found:** 22 of the sesh.toml paths used trailing slashes (the spabreaks family, booking-transform, contacts, blog, wss, wss-data, my-account, voucher-portal, opencode); the remaining sessions omitted them and worked fine
- **Found:** _tmux_git-repo (home/programs/tui/tmux/git-repo.nix:13-16) amplified the error by opening 4 new windows via tmux new-window, each inheriting the trailing-slash cwd
- **Found:** nushell config.nu was ruled out as a defensive fix site: the validation fires in engine-state init before config.nu is parsed, so a guard there could not intercept it
- **Decided:** Normalize all 22 paths in sesh.toml (single chokepoint) rather than patching _tmux_git-repo, since the latter would not cover sessions using other startup commands (task console, make psql, ssh, etc.)
- **Decided:** Skip the defensive config.nu PWD-normalization guard: user explicitly declined it, and it would fire too late (after engine_state init) to help
- **Open:** Verify on the host after switching: `sesh connect config-opencode` and one spabreaks session should start with no nu::shell::error and nvim/gitui windows should spawn cleanly

## [91546de] Fix: port ftplugins to native nvim 0.12 treesitter APIs

Replaced the broken markdown ftplugin with the proven cast version (battle-tested in the container with nvim 0.12). Ported the ruby ftplugin to the same pattern. Fixed the global foldexpr in settings.lua.

Files changed:
- home/config/nvim/ftplugin/markdown/init.lua — replaced verbatim with cast version from /home/pl/.config/cast/nix/runtime/ftplugin/markdown/init.lua
- home/config/nvim/ftplugin/ruby/init.lua — ported to same pattern: pure functions, vim.iter filtering, buffer-scoped keymaps, native foldexpr, node:type()=="call" filter to dedup RSpec block captures
- home/config/nvim/lua/config/settings.lua:44 — foldexpr updated from nvim_treesitter#foldexpr() to v:lua.vim.treesitter.foldexpr()

Commit: 91546de

- **Found:** The cast version at /home/pl/.config/cast/nix/runtime/ftplugin/markdown/init.lua was already a clean port of the host's old code, purpose-built for nvim 0.12 with no plugin dependency
- **Found:** Only markdown ftplugin exists in cast runtime — no ruby equivalent, so ruby was ported from scratch following the same pattern
- **Found:** No remaining active references to nvim-treesitter.ts_utils or nvim_treesitter#foldexpr() in the config — only in comments documenting the migration
- **Decided:** Used the cast markdown ftplugin verbatim — it is proven in the container with nvim 0.12 and has better architecture (pure functions, buffer-scoped keymaps, luaCATS docs)
- **Decided:** For ruby ftplugin: used node:type()=='call' filter to skip @method identifier captures and only collect @rspec_block call nodes — avoids duplicate rows from the two-capture query
- **Decided:** Navigation filtering: r > cur for next, r < cur for prev (strictly after/before cursor) — matches cast markdown behavior
- **Decided:** Also fixed settings.lua:44 global foldexpr even though it was a no-op (foldmethod='indent') — same root cause, prevents future breakage if foldmethod changes
- **Decided:** Kept the _spec.rb guard at the top of ruby ftplugin before any require or query parse

