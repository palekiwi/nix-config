---
status: open
priority: low
refs:
- master/task/1783052920-60a7d6c/migrate-to-nixpkgs-2605.md
- nix-migrate-to-26-05/plan/1783744071-82de11f/migrate-nixpkgs-2605.md
---
# nixpkgs 26.05 deprecation warnings

Warnings surfaced during `home-manager switch` after bumping to 26.05.
All are non-blocking (gated by `home.stateVersion < "26.05"`).
Current stateVersion is `"25.05"` (set in `home/users/pl/deck.nix:13`).

## Items

- [x] **`programs.neovim.withRuby`** — set `withRuby = false` in `home/programs/tui/nvim.nix`
  Accepted new default. No plugins require the Ruby neovim provider.

- [x] **`programs.neovim.withPython3`** — set `withPython3 = false` in `home/programs/tui/nvim.nix`
  Accepted new default. No plugins require the Python3 neovim provider.

- [x] **`gtk.gtk4.theme`** — set `gtk4.theme.name = "Breeze-Dark"` in `home/programs/gui/gtk.nix`
  Explicit value matches existing gtk3 theme.

- [x] **`programs.firefox.configPath`** — pinned to `.mozilla/firefox` in `home/programs/gui/firefox.nix`
  Silences warning without requiring directory migration. Migrating to XDG
  path is a separate task (requires moving `~/.mozilla/firefox` on disk).

- [x] **`programs.ssh.matchBlocks`** deprecated — use `programs.ssh.settings`
  Migrated in `home/programs/tui/ssh.nix`. Directive names now use canonical
  SSH casing (HostName, User, Port). Empty `Host *` placeholder dropped.
  Verified via `nix eval` -- no deprecation warning, generated config identical.

## xorg package set deprecated (home-manager)

- [x] `xorg.xhost` → `xhost` in `home/programs/gui/xorg.nix`
- [x] `xorg.xev` → `xev` in `home/programs/gui/xorg.nix`
- [x] `xorg.xmodmap` → `xmodmap` in `home/programs/gui/xorg.nix`
- [x] `xorg.xset` → `xset` in `home/programs/gui/xorg.nix`

## xorg package set deprecated (system configs)

- [x] `xorg.xrandr` → `xrandr` in `vm/claude/default.nix:38-40`
- [x] `xorg.xrandr` → `xrandr` in `modules/awesome.nix:32`

## nvim plugin deprecations (nvim 0.12 API changes)

Surfaced via `:checkhealth vim.deprecated`. All are warnings only —
nothing is broken. Removed in nvim 0.13. Fixes require upstream plugin
updates pulled via `:Lazy update`; no config file changes needed.

- [ ] `vim.lsp.get_buffers_by_client_id()` in `rustaceanvim`
  Source: `rustaceanvim/lua/rustaceanvim/server_status.lua:52`
  Action: `:Lazy update rustaceanvim`

- [ ] `vim.validate{<table>}` (old table API) in `prettier.nvim`
  Source: `prettier.nvim/lua/prettier/options.lua:101,124`
  Action: `:Lazy update prettier.nvim`

- [ ] `vim.validate{<table>}` (old table API) in `grapple.nvim`
  Source: `grapple.nvim/lua/grapple/scope_manager.lua:74`
  Appears twice: direct load and via lualine component loader.
  Action: `:Lazy update grapple.nvim`

## Deferred tasks

- [ ] **Firefox XDG migration** — move `~/.mozilla/firefox` to
  `$XDG_CONFIG_HOME/mozilla/firefox` on disk, then update `firefox.nix`:
  `programs.firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";`
  Note: native messaging hosts are not moved automatically.
