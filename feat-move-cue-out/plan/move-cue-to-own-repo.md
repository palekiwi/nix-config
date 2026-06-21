---
status: open
---
# Plan: Move cue.nvim to Independent Repository

## Phase 1: Extract and Push Plugin
1. Create a split branch containing only the `home/config/nvim/plugins/cue.nvim/` history.
   ```bash
   git subtree split -P home/config/nvim/plugins/cue.nvim -b cue-plugin-split
   ```
2. Push the split branch to the new repository.
   ```bash
   cd /home/pl/code/palekiwi-labs/cue.nvim
   git pull /home/pl/nix-config cue-plugin-split
   git push origin master
   ```
3. Add a basic `README.md` and `LICENSE` to the new repository if they are missing.

## Phase 2: Update nix-config
1. Remove the local plugin directory.
   ```bash
   rm -rf home/config/nvim/plugins/cue.nvim/
   ```
2. Update `home/config/nvim/lua/config/plugins/cue.lua` to reference the new repository.
   ```lua
   return {
     {
       "palekiwi-labs/cue.nvim",
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
3. Verify the configuration by running Neovim (if possible) or just checking the file.

## Phase 3: Cleanup
1. Remove the temporary split branch in `nix-config`.
   ```bash
   git branch -D cue-plugin-split
   ```
