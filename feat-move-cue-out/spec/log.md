# Project Log

## [bdc0e35-dirty] move cue.nvim to independent repository

Moved the cue.nvim plugin from a local directory within the nix-config repository to an independent repository at /home/pl/code/palekiwi-labs/cue.nvim.

Details:
- Copied plugin files (lua/ and plugin/) to the new repository.
- Removed local source in nix-config at home/config/nvim/plugins/cue.nvim/.
- Removed the obsolete monolithic utility file at home/config/nvim/lua/config/utils/cue.lua.
- Updated the lazy.nvim spec in home/config/nvim/lua/config/plugins/cue.lua to point to 'palekiwi-labs/cue.nvim'.
- Staged only relevant files to avoid including the .cue/ directory in the nix-config history.

- **Found:** .cue/ directory contains its own .git and was being picked up as a submodule entry by 'git add .'
- **Decided:** Move cue.nvim to independent repository
- **Decided:** Do not preserve history (one-time move)
- **Decided:** Update lazy.nvim spec to reference GitHub repo instead of local path

## [df38e18] enable dev mode for cue.nvim

Updated the cue.nvim plugin specification in nix-config to enable local development mode.

Changes:
- Added 'dev = true' to the plugin spec.
- Added 'dir = "~/code/palekiwi-labs/cue.nvim"' to explicitly point to the new independent repository location, bypassing the default 'dev.path' in lazy.nvim.
- Committed the change to nix-config.

- **Decided:** Use local directory for cue.nvim development via explicit 'dir' property in lazy spec.

## [5e08d7e] pin cue.nvim to master branch

Pinned the cue.nvim plugin to the 'master' branch in the nix-config specification.

Rationale:
When 'dev = true' and 'dir' are used, Neovim sources directly from the file system. However, explicitly setting 'branch = "master"' provides a safeguard if lazy.nvim attempts to reconcile the checkout state or if the user wants to ensure stability while switching branches in the plugin repository.

Changes:
- Added 'branch = "master"' to home/config/nvim/lua/config/plugins/cue.lua.
- Committed change to nix-config.

- **Decided:** Pin cue.nvim to master branch to prevent sourcing unstable feature branches during development.

