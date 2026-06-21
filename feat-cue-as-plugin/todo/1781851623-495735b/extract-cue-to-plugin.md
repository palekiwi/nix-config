---
status: complete
priority: 1
---
# Extract cue to a neovim plugin

## Context

`cue.lua` is currently a monolithic 986-line utility module tightly coupled to the
personal neovim config under `lua/config/utils/cue.lua`. Highlights live in
`lua/config/setup/highlights.lua` and keymaps are hardwired in
`lua/config/mappings.lua`.

The goal is to restructure this into a proper local neovim plugin (`cue.nvim`)
living under the nvim config directory, loaded via lazy.nvim `dir =` pointing to
a local path. Once stable it can be extracted to its own git repo.

## Relevant files

- `home/config/nvim/lua/config/utils/cue.lua` (986 lines — all plugin logic)
- `home/config/nvim/lua/config/setup/highlights.lua` (lines 48-61 — cue highlights)
- `home/config/nvim/lua/config/mappings.lua` (lines 10, 46-101 — cue keymaps)
- `home/config/nvim/lua/config/lazy.lua` (lazy.nvim bootstrap + dev path config)

## Plan

See master plan: `feat/cue-as-plugin/plan/extract-cue-to-plugin.md`

## Checklist

- [x] Create plugin directory structure under nvim config
- [x] Split cue.lua into focused modules (config, highlights, picker, log, commands)
- [x] Implement `setup(opts)` entry point in `lua/cue/init.lua`
- [x] Create `plugin/cue.lua` autoload guard
- [x] Wire lazy.nvim spec with `dir =` local path
- [x] Remove `require('config.utils.cue')` from personal config
- [x] Extract cue highlights out of shared highlights.lua
- [x] Update mappings.lua to call `require('cue')` instead
- [x] Smoke-test all commands and keymaps in nvim
- [x] Verify lazy-loading works correctly
