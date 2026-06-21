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

