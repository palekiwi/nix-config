---
status: open
---
# Plan: Extract cue.lua to a proper neovim plugin

**Branch:** `feat/cue-as-plugin`
**Todo:** `.cue/feat-cue-as-plugin/todo/1781851623-495735b/extract-cue-to-plugin.md`

## Goal

Transform the monolithic `cue.lua` utility into a self-contained local neovim
plugin (`cue.nvim`) following proper plugin conventions. Load it via lazy.nvim
`dir =` pointing to a local path inside the nix-config repo. This keeps
everything in one place during development; the plugin can later be extracted to
its own git repo.

---

## Target directory layout

```
home/config/nvim/plugins/cue.nvim/
├── lua/
│   └── cue/
│       ├── init.lua        -- public API: setup(opts), re-exports public fns
│       ├── config.lua      -- default config table + apply(user_opts)
│       ├── highlights.lua  -- setup() calls vim.api.nvim_set_hl
│       ├── picker.lua      -- telescope pickers: pick_artifacts, pick_context, etc.
│       ├── log.lua         -- log_form, log_add, parse_log_buffer
│       └── commands.lua    -- nvim_create_user_command registrations
└── plugin/
    └── cue.lua             -- autoload guard only (vim.g.loaded_cue)
```

---

## Phase 1 — Scaffold plugin skeleton

1. Create `home/config/nvim/plugins/cue.nvim/` directory tree (all empty files).
2. Write `plugin/cue.lua` with loaded guard:
   ```lua
   if vim.g.loaded_cue then return end
   vim.g.loaded_cue = true
   ```
3. Write `lua/cue/config.lua` with defaults table:
   - `DONE_STATUSES`, `TYPE_DEFAULTS`, `category_highlights` colour map
   - `function M.apply(opts)` merges user opts with defaults
4. Write `lua/cue/init.lua` skeleton:
   ```lua
   local M = {}
   function M.setup(opts) ... end
   return M
   ```

## Phase 2 — Extract highlights

Source: `home/config/nvim/lua/config/setup/highlights.lua:48-61`

1. Move `cue_highlights()` body into `lua/cue/highlights.lua` as `M.setup()`.
2. Remove the `cue_highlights()` function and its call from `highlights.lua`.
3. Call `require('cue.highlights').setup()` inside `cue/init.lua`'s `setup()`.

## Phase 3 — Extract picker

Source: `home/config/nvim/lua/config/utils/cue.lua:1-12, 89-534, 622-748`

Functions to move to `lua/cue/picker.lua`:
- `get_cue_artifacts(opts)`
- `make_mem_entry_maker(opts)`
- `sort_artifacts(artifacts)`
- `M.pick_artifacts(opts)`
- `M.pick_context()`
- `M.pick_branch_artifacts()`
- `M.ui_pick()`
- `select_branch_helper(callback)` (private)
- `select_category(callback)` (private)
- All telescope `require` statements at top of file

## Phase 4 — Extract log

Source: `home/config/nvim/lua/config/utils/cue.lua:750-888`

Functions to move to `lua/cue/log.lua`:
- `parse_log_buffer(lines)` (private)
- `M.log_add(entry)`
- `M.log_form()`
- `LOG_TEMPLATE` constant

## Phase 5 — Extract commands

Source: `home/config/nvim/lua/config/utils/cue.lua:892-984`

Move all `vim.api.nvim_create_user_command(...)` blocks to `lua/cue/commands.lua`
as a `M.setup()` function called from `cue/init.lua`.

Commands: `CueLog`, `CueAdd`, `CueAddBin`, `CueAddTrace`, `CueAddTmp`,
`CueAddRef`, `CueAddDoc`

Also keep the remaining small functions in `init.lua` or a `core.lua`:
- `M.open_context()`
- `M.open_log()`
- `M.add(filename, opts)`
- `M.add_with_title(type, branch)`
- `M.add_spec(branch)`
- Private helpers: `slugify`, `execute_command`, `parse_json`,
  `get_current_branch`, `prompt_filename`, `prompt_root_and_add`,
  `select_root`, `is_done`, `is_archived`, `is_finished`

## Phase 6 — Wire lazy.nvim

Add a new plugin spec file `home/config/nvim/lua/config/plugins/cue.lua`:

```lua
return {
  {
    "cue.nvim",
    dir = vim.fn.stdpath("config") .. "/../plugins/cue.nvim",
    -- OR use an absolute path relative to nix-config
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
    },
    config = function()
      require("cue").setup({})
    end,
  }
}
```

> Note: `vim.fn.stdpath("config")` resolves to the nvim config dir. The plugin
> lives at `../plugins/cue.nvim` relative to that. Verify the actual resolved
> path before committing.

## Phase 7 — Update personal config wiring

1. **`mappings.lua`**: Change `require('config.utils.cue')` → `require('cue')`.
   All `cue_utils.*` call-sites remain identical since `init.lua` re-exports all
   public functions.
2. **`config/utils/cue.lua`**: Delete the file entirely once plugin is wired.

## Phase 8 — Smoke test

Verify in a live nvim session:
- [ ] `:CueLog`, `:CueAdd`, `:CueAddTrace` etc. all work
- [ ] `<C-t>`, `<space>et`, `<space>nt` keymaps fire correctly
- [ ] `<space>mc` (open context), `<space>ml` (open log) work
- [ ] Highlights (`CueCategoryTodo`, `CueStatusDone`, etc.) are applied
- [ ] No `require` errors on startup
- [ ] Lazy-loading: plugin loads on first keymap/command, not at startup

---

## Key constraints

- **No hardwired keymaps inside the plugin** — all key bindings remain in
  `mappings.lua` in the personal config, calling `require('cue').*`.
- **Snacks dependency**: `Snacks.picker.select`, `Snacks.input`, `Snacks.win`
  are used heavily — must declare `folke/snacks.nvim` as a dependency in the
  lazy spec.
- **Telescope dependency**: all picker logic requires telescope — declare as dep.
- **`vim.g.git_master` / `vim.g.git_base`**: these globals are set by the
  personal config (`globals.lua`); the plugin reads but never sets them.
- The `lazy.lua` already has a `dev.path = "~/code/neovim/plugins/"` — we will
  NOT use that path; we use an explicit `dir =` instead to keep the plugin
  inside the nix-config repo.

---

## Open questions (resolved)

- Location: local `dir =` inside nix-config nvim directory (not `dev.path`).
- Scope: option 2 — local plugin, extractable to own repo later.
- Keymaps: remain in personal config, not inside the plugin.
