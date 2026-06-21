# Project Log

## [27f32a0-dirty] feat: cue.nvim plugin scaffold complete

Extracted the monolithic config/utils/cue.lua (986 lines) into a properly structured local neovim plugin at home/config/nvim/plugins/cue.nvim/. Wired via lazy.nvim dir= spec. All public functions re-exported through init.lua so mappings.lua required only a one-line require path change.

- **Found:** Plugin path resolves at runtime: vim.fn.fnamemodify(vim.fn.stdpath('config'), ':h') .. '/plugins/cue.nvim' — works regardless of checkout location
- **Found:** The original config/utils/cue.lua is intentionally retained until smoke-tested in a live nvim session
- **Found:** highlights.lua COLORS table is a global (no local) — duplicated into cue/highlights.lua with its own local COLORS; no conflict
- **Found:** commands.lua inlines prompt_root_and_add and select_category as local helpers (they were private in the original and only used by commands)
- **Found:** Snacks is required lazily (inside function bodies) in core.lua and picker.lua to avoid load-order issues
- **Decided:** Use vim.fn.fnamemodify(stdpath('config'), ':h') to compute plugin path dynamically rather than a hardcoded absolute path
- **Decided:** Keep original cue.lua alive temporarily — delete in a follow-up commit after smoke test confirms the plugin works
- **Decided:** No keymaps inside the plugin — all bindings remain in mappings.lua calling require('cue').*
- **Decided:** cue/core.lua houses shared private helpers (slugify, execute_command, parse_json, get_current_branch) plus all non-picker, non-log public API
- **Open:** Smoke test needed: launch nvim and verify all :Cue* commands, picker keymaps, and highlights work
- **Open:** After smoke test passes: delete home/config/nvim/lua/config/utils/cue.lua and commit

## [263993d-dirty] fix: local plugin path for nix-config

Corrected the plugin path calculation in the lazy.nvim spec. Under the nix setup, `stdpath('config')` already points to the nvim configuration directory. Since the `plugins/` directory was placed inside the nvim config directory by home-manager, using `fnamemodify(..., ':h')` was incorrectly looking for the plugin in the parent directory of the config.

- **Found:** stdpath('config') resolves to the directory managed by home-manager's home.file.".../nvim" rule.
- **Decided:** Directly use stdpath('config') .. '/plugins/cue.nvim' as the plugin path.

## [2c10029-dirty] cue.nvim aligned with updated cue framework (tasks)

- **Found:** `add_with_title` needed hardcoded logic to enforce the master-only rule for tasks to ensure framework compliance.
- **Decided:** `task` artifacts always live on master branch regardless of current branch.
- **Decided:** `task` is now the primary artifact type (keybind `t`), demoting `todo` (moved to `o`).
- **Decided:** Task picker (`<space>et`) and current artifact picker (`<C-t>`) remain separate actions as requested.

