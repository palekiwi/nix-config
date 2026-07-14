---
status: open
refs: master/task/1783052920-60a7d6c/migrate-to-nixpkgs-2605.md
---
# Plan: Migrate to nixpkgs 26.05

## Goal

Bump both flakes from `nixos-25.11` to `nixos-26.05` and fix the neovim
treesitter configuration to be compatible with neovim 0.12, which ships in
26.05.

---

## Context

- System flake: `/home/pl/nix-config/flake.nix`
- Home-manager flake: `/home/pl/nix-config/home/flake.nix`
- Neovim is managed exclusively by the **standalone** home-manager flake.
  The system flake does not install neovim. Neovim version is therefore
  controlled by `home/flake.nix`'s nixpkgs pin.
- `nvim-treesitter` `master` branch is frozen and incompatible with nvim 0.12.
  The plugin was fully rewritten on the `main` branch.
- `tree-sitter` CLI is already available via `home/programs/tui/dev.nix:17`
  (imported unconditionally by `tui/default.nix`). No change to `nvim.nix`
  needed.
- The `render-markdown.nvim` plugin declares `nvim-treesitter` as a lazy.nvim
  dependency. Since treesitter stays in lazy.nvim this requires no change.

## Future phase (deferred)

Migrate to Nix-managed parsers via `vimPlugins.nvim-treesitter.withPlugins` as
part of the broader neovim wrapper module refactor (reference implementation in
`/home/pl/.config/cast/nix/nvim.nix` using `nvf`).

---

## Order of operations

Home-manager **before** system. The neovim binary version comes from the
home-manager flake's nixpkgs pin. The system flake does not own neovim on the
main hosts (deck, pale, sayuri, kyomu). Therefore:

1. Fix nvim config (unblocks everything, must land before switching to nvim 0.12)
2. Bump `home/flake.nix`, update lock, switch home-manager → neovim 0.12 arrives
   with correct config
3. Bump `flake.nix` (system), update lock, nixos-rebuild

---

## Changes

### 1. Rewrite `treesitter.lua`

**File:** `home/config/nvim/lua/config/plugins/treesitter.lua`

Remove: old `nvim-treesitter.configs` module, `ensure_installed` in setup,
`auto_install`, `parser_install_dir`, `vim.opt.runtimepath:append()` preamble,
`nvim-treesitter-refactor` entry.

New spec targets `branch = "main"`. Parser installation moves to an `init`
callback using the new install API (diff against already-installed to avoid
reinstalling on every startup). Highlighting moves to a `FileType` autocmd
using `vim.treesitter.start()`. Indentation set via `vim.bo.indentexpr`.

```lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    init = function()
      -- install parsers not already present
      local wanted = {
        "vimdoc", "bash", "ini", "json", "yaml", "git_config", "gitignore",
        "sxhkdrc", "c", "cmake", "rust", "toml", "lua", "python",
        "javascript", "typescript", "html", "css", "astro", "dockerfile",
        "go", "ruby", "vue", "nu", "nix",
      }
      local installed = require("nvim-treesitter.config").get_installed()
      local missing = vim.iter(wanted)
        :filter(function(p) return not vim.tbl_contains(installed, p) end)
        :totable()
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end

      -- highlighting and indentation via FileType autocmd
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
```

### 2. Delete `treesitter-text-objects.lua`

**File:** `home/config/nvim/lua/config/plugins/treesitter-text-objects.lua`

Delete entirely. Plugin unused; uses the dead `nvim-treesitter.configs` API.

### 3. Bump `home/flake.nix`

**File:** `home/flake.nix`

```
line 5:  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"
      →  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"

line 8:  url = "github:nix-community/home-manager/release-25.11"
      →  url = "github:nix-community/home-manager/release-26.05"
```

Then: `nix flake update` in `home/`.

### 4. Bump `flake.nix` (system)

**File:** `flake.nix`

```
line 5:  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"
      →  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"

line 16: url = "github:nix-community/home-manager/release-25.11"
      →  url = "github:nix-community/home-manager/release-26.05"
```

Then: `nix flake update` in root.

Note: `sops-nix`, `claude-desktop`, and `notifications-server` all follow
nixpkgs via `inputs.nixpkgs.follows = "nixpkgs"`. No changes needed for them.

---

## Post-switch steps (runtime, on host machine)

After `home-manager switch` brings nvim 0.12:

1. Open nvim — lazy.nvim will detect `nvim-treesitter` has moved to `main`
2. `:Lazy update nvim-treesitter` — pull the new `main` branch
3. `:TSUninstall all` — remove old parsers compiled by the `master` branch
4. Restart nvim
5. `:TSUpdate` — recompile parsers with new toolchain
6. `:checkhealth nvim-treesitter` — verify everything is wired up

---

## Files changed summary

| File | Action |
|------|--------|
| `home/config/nvim/lua/config/plugins/treesitter.lua` | Rewrite |
| `home/config/nvim/lua/config/plugins/treesitter-text-objects.lua` | Delete |
| `home/flake.nix` | Bump versions + flake update |
| `flake.nix` | Bump versions + flake update |
