# Research: Moving cue.nvim to Its Own Repository

## Current State
- The `cue.nvim` plugin is currently a local plugin within the `nix-config` repository.
- Location: `home/config/nvim/plugins/cue.nvim/`
- Configuration: `home/config/nvim/lua/config/plugins/cue.lua`
- The plugin depends on:
  - `nvim-telescope/telescope.nvim`
  - `folke/snacks.nvim`
  - A system-level `cue` binary.

## Target Repository
- Path: `/home/pl/code/palekiwi-labs/cue.nvim`
- Remote: `git@github.com:palekiwi-labs/cue.nvim.git`
- Status: Initialized, mostly empty.

## History Extraction
- The plugin was extracted in commit `27f32a0`.
- Using `git subtree split` would preserve the history of these two commits.

## Integration in `nix-config`
- Currently uses a local path resolved at runtime.
- Plan to transition to a standard repository reference: `palekiwi-labs/cue.nvim`.
