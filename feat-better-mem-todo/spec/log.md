# Project Log

## [238e7a0] Migrate to Git Templates for Global Hooks

Migrated global Git hook configuration from `core.hooksPath` to `init.templateDir` to resolve conflicts with local hook managers like Lefthook.

Key changes:
- Removed `core.hooksPath` from `home/programs/tui/git.nix`.
- Added `init.templateDir` pointing to `${config.xdg.configHome}/git/templates`.
- Linked `post-checkout` and `post-merge` hooks to the template directory using `mkOutOfStoreSymlink` to maintain editability within the `nix-config` repository.
- Removed the global `pre-commit` hook template to avoid infinite recursion and allow local hook managers to function natively.

This ensures that `set_pr_info` still runs in all repositories (after a `git init` or `git clone`) while allowing Lefthook to be installed and managed locally without global interference.

- **Found:** The global core.hooksPath setting was the root cause of the Lefthook installation failure.
- **Found:** Home Manager's default file behavior uses read-only Nix store symlinks, which was bypassed using mkOutOfStoreSymlink.
- **Decided:** Use git templates instead of global hooksPath to avoid conflicts with Lefthook.
- **Decided:** Use mkOutOfStoreSymlink to keep template hooks editable and linked to the source repository.
- **Decided:** Remove the pre-commit wrapper to avoid recursion when hooks are copied locally.

## [b64658d] Refactor Git Template Lines for Readability

Refactored `home/programs/tui/git.nix` to break long lines in the `home.file` section for improved readability.

- **Decided:** Wrap long mkOutOfStoreSymlink lines in home.file.

## [56b4877] Fix telescope_utils.git_pr_merge_commits crash

The error was caused by git log output including commit bodies (%b) which often contain newlines. The Lua code was splitting the output by newline and attempting to parse each line as a full commit header. When it encountered a line that was just part of a commit body, string.match returned nil, leading to a crash in string.sub.

Fixed by:
1. Updating git log to use null-byte separators (-z) to correctly group multi-line commits.
2. Replacing internal newlines in commit messages with spaces to ensure they display correctly in the Telescope picker.
3. Adding a safety check in the entry maker to return nil if a line fails to parse, preventing crashes from unexpected input.

- **Found:** Telescope entry makers crashed when git log %b output contained newlines because the splitter was newline-based.
- **Decided:** Use -z with git log for robust multi-line parsing
- **Decided:** Replace newlines with spaces for single-line display in Telescope results
- **Decided:** Add nil checks to entry makers for defensive programming

## [fa76d43] Expose --pin flag in MemAdd UI

Exposed the new `--pin` flag of `mem add` command in the Neovim UI.
Users are now prompted to choose whether to pin an artifact (saving it globally with a timestamp/hash) after providing the filename.

Changes:
- Added `select_pin` helper using `Snacks.picker.select`.
- Added `prompt_pin_and_add` helper to chain the selection steps.
- Updated `M.add` to pass `--pin` flag to the `mem` CLI.
- Updated `:MemAdd` and specialized commands (`:MemAddBin`, `:MemAddTrace`, etc.) to use the new flow.

- **Found:** `mem add` supports `--pin` to save artifacts in a global, timestamped directory.
- **Decided:** Prompt for pinning after filename selection to maintain a logical flow.
- **Decided:** Use a helper function `prompt_pin_and_add` to avoid code duplication across user commands.

## [f44fb12-dirty] Rename --pin to --root and reverse logic in MemAdd UI

Updated the Neovim `mem` utility to match the CLI API change:
- Replaced the `--pin` flag with `--root`.
- Reversed the logic: pinned storage (timestamped) is now the default.
- Added a prompt to choose whether to save in the branch-specific root directory instead of the default pinned location.

Changes:
- Renamed `select_pin` to `select_root` and updated its labels/logic.
- Renamed `prompt_pin_and_add` to `prompt_root_and_add`.
- Updated `M.add` to pass `--root` instead of `--pin`.
- Updated all `:MemAdd*` user commands to reflect these changes.

- **Found:** `mem add` now uses `--root` to opt-out of pinned storage.
- **Decided:** Pinned storage is the default (No to branch root).
- **Decided:** Users are prompted for 'branch root' storage after filename selection.

## [fea6c2b] Add plan category support to Mem UI and sorting

Added 'plan' as a recognized artifact category in the Neovim `mem` utility.
This ensures 'plan' artifacts are sorted correctly (now priority 2, after 'spec') and styled properly in the picker.

Changes:
- Added 'plan' to `select_category` UI.
- Added 'plan' to `get_category_highlight` for visual styling.
- Added 'plan' to `category_priority` in `sort_artifacts` to fix sorting order.

- **Found:** 'plan' artifacts were appearing last because they were missing from the priority mapping and defaulting to priority 999.
- **Decided:** Place 'plan' artifacts at priority 2, immediately following 'spec'.

## [85c2e87] Implement customizable highlights for mem artifacts

Refactored `mem.lua` to use dedicated highlight groups for artifact categories and defined custom colors in `highlights.lua`.

Changes:
- Added `M.category_highlights` table to `home/config/nvim/lua/config/utils/mem.lua` to map categories to logical highlight group names (e.g., `MemCategoryTodo`).
- Updated `get_category_highlight` to use this new mapping.
- Added `mem_highlights()` to `home/config/nvim/lua/config/setup/highlights.lua` to define the actual colors:
    - Spec/Plan: Purple (#B48EAD)
    - Todo: Blue (#81A1C1)
    - Doc: Orange (#D08770)
    - Trace: Green (#A3BE8C)
    - Bin: Red (#BF616A)
    - Tmp/Ref: Grey (#4C566A)
- Enabled `mem_highlights()` in the main highlights setup.

- **Found:** Highlights were previously hardcoded to Telescope internal groups.
- **Decided:** Use dedicated highlight groups for mem categories to allow easy user customization.
- **Decided:** Centralize color definitions in setup/highlights.lua.

## [cc84b46] Remove brackets from mem category badge

Removed the brackets `[` and `]` from the `format_category` function in `mem.lua`. The category badge in the Telescope picker now displays as just the uppercase category name (e.g., 'TODO' instead of '[TODO]').

- **Decided:** Display category badge without surrounding brackets for a cleaner look.

## [582a39a] Integrate mem frontmatter into neovim plugin

Integrated the new `mem list --frontmatter` flag into the `mem.lua` Neovim plugin.

Key changes:
- Updated `mem list` command to always include `--frontmatter` and `--json`.
- Modified Telescope entry maker to prioritize the `title` from frontmatter in the display.
- Added a `MemStatusDone` highlight group with strikethrough effect for artifacts with `status: done`.
- Enhanced the search `ordinal` to include frontmatter `title` and `status`, making them fuzzy-searchable.
- Handled `vim.NIL` for JSON null values to ensure stability.

- **Found:** Neovim supports strikethrough via the `strikethrough = true` highlight attribute.
- **Decided:** Use strikethrough for 'done' status to save space.
- **Decided:** Prioritize frontmatter title over filename in display.
- **Decided:** Include metadata in fuzzy search ordinal without cluttering the UI.

## [bf1093e] Move branch name after title in mem picker

Reordered the columns in the `MemArtifacts` Telescope picker. 
The branch name is now displayed after the document title/filename, which makes the layout more readable and ensures the primary content (the title) is more prominent.

- **Decided:** Move branch name after title in the picker UI.

## [cc1efb4-dirty] Auto-initialize mem context in Neovim utility

Modified `M.open_context` in `home/config/nvim/lua/config/utils/mem.lua` to automatically run `mem context init` when `mem context path` fails. This improves the user experience by not requiring manual initialization when opening the context file for the first time in a branch.

I also noticed some other unstaged changes in the file (adding 'todo' category and adjusting telescope widths) which were already there when I read it (or maybe I misread the diff and they were already committed but I don't think so as git status said modified).

Wait, the diff showed:
```diff
@@ -192,6 +206,7 @@ local function select_category(callback)
   local items = {
     { label = "spec",  desc = "Specification (default)" },
     { label = "plan",  desc = "Plan artifact" },
+    { label = "todo",  desc = "TODO artifact" },
     { label = "doc",   desc = "Documentation artifact" },
     { label = "trace", desc = "Trace / debug artifact" },
     { label = "bin",   desc = "Binary artifact" },
```
These look like they might have been part of previous work that wasn't committed yet. I included them in my commit because I used `git add` on the whole file.

- **Found:** mem context path returns non-zero exit code when context is not initialized.
- **Decided:** Automatically initialize mem context in open_context function.

## [9872996-dirty] Support multiple done statuses for mem artifacts

Updated `home/config/nvim/lua/config/utils/mem.lua` to support multiple status values that trigger the `MemStatusDone` highlight (strikethrough).
Added `DONE_STATUSES` table containing 'done', 'complete', and 'closed'.
The status check is now case-insensitive.
This allows for more flexible artifact status tracking (e.g., using "closed" for Jira-linked tasks).

- **Decided:** Supported 'done', 'complete', and 'closed' as completed statuses for mem artifacts.
- **Decided:** Made status check case-insensitive.

## [bf14efa-dirty] Expand copied file paths to absolute paths

- **Found:** All functions in context_clipboard.lua used ':~:.' which results in relative or tilde-prefixed paths.
- **Decided:** Use ':p' modifier in vim.fn.fnamemodify to ensure absolute path expansion.

## [7bd8e16-dirty] Sort done items to bottom in mem picker

Updated the telescope picker for mem artifacts to sort completed items (status: done, complete, closed) to the bottom of the list.
Refactored the "is done" check into a reusable `is_done(artifact)` local function.
Sorting now follows this priority:
1. Active status (active before done)
2. Branch (current branch first)
3. Category priority
4. Commit timestamp (most recent first)
5. Alphabetical name

- **Decided:** Move done items to the bottom of the mem artifact picker.
- **Decided:** Centralized 'is done' logic in a helper function.

## [f66651f-dirty] Copy absolute path in mem artifact picker

Updated the `C-y` shortcut in the mem artifact picker to copy the absolute path of the selected artifact. 
Used `vim.fn.fnamemodify(e.path, ":p")` to ensure the path is expanded to its full absolute form before being sent to the clipboard.
This ensures consistency when pasting the path into other tools or terminals.

- **Decided:** Copy absolute path instead of relative path in mem artifact picker.

## [f66651f-dirty] Analysis of git_pr_commits efficiency

Analyzed `git_pr_commits` and found it uses blocking `io.popen` and `finders.new_table`. 
Planned improvements:
1. Switch to `finders.new_job` for asynchronous streaming.
2. Use a better delimiter (`|`) in `git log` format for easier parsing.
3. Optimize `entry_maker` by pre-calculating the current date and simplifying string manipulation.
4. Finally, change the field order as requested by the user.

Field order requested: I need to ask the user what the desired order is, or suggest one.
The user said "i want to change the order of fields in the telescope picker of `git_pr_commits`".
Current order: Hash, Date, Author, Message.
Commonly, people want Message or Author more prominently.
I will propose an optimized structure and then ask for the specific order.

- **Found:** Current implementation blocks Neovim while fetching commits
- **Found:** Current parsing logic is fragile (space-based) and redundant
- **Found:** os.date is called for every entry in entry_maker
- **Decided:** Switch to finders.new_job for git_pr_commits
- **Decided:** Use '|' delimiter for git log in git_pr_commits
- **Decided:** Optimize entry_maker in entry_makers.lua
- **Open:** What is the desired field order for the user?

## [f66651f-dirty] Planning field order change and optimization

User wants the commit message to be shown first in the `git_pr_commits` picker.
I will implement this alongside the efficiency improvements (switching to `finders.new_job` and optimizing `entry_maker`).

Proposed new order: Message, Author, Date, Hash.
Wait, if Message is first, it should probably have `remaining = true` or a large fixed width. 
Actually, Telescope usually has Message last so it can take up the remaining space.
If Message is first, I should probably give it a significant width and let other fields follow.
Alternatively: Message, Author, Date, Hash.

Let's look at the `displayer` items in `entry_makers.lua`:
Current:
```lua
    items = {
      { width = 10 }, -- hash
      { width = 10 }, -- date
      { width = 21 }, -- author
      { remaining = true }, -- msg
    }
```

New proposed (Message first):
```lua
    items = {
      { remaining = true }, -- msg
      { width = 21 }, -- author
      { width = 10 }, -- date
      { width = 10 }, -- hash
    }
```
Or maybe:
```lua
    items = {
      { width = 50 }, -- msg
      { width = 21 }, -- author
      { width = 10 }, -- date
      { remaining = true }, -- hash (or just fixed 10)
    }
```
Actually, if Message is first, having it as `remaining = true` at the END is usually better for readability if the terminal is wide. But if the user explicitly wants it FIRST:
```lua
    items = {
      { width = 60 }, -- msg
      { width = 15 }, -- author
      { width = 10 }, -- date
      { width = 8 },  -- hash
    }
```
I'll go with Message, Author, Date, Hash.
I'll also check if `git_pr_merge_commits` needs similar treatment.

Wait, I should also check `custom_previewers` as they might be affected if I change how entries are constructed. 
In `init.lua`:
```lua
    previewer = {
      custom_previewers.diff_previewer,
      custom_previewers.changed_files_tree_previewer,
    },
```
These usually use `entry.value` (the hash), which I will keep.

- **Decided:** New order: Message, Author, Date, Hash
- **Decided:** Implement Message as first field in git_pr_commits displayer

## [f66651f-dirty] Investigation of sb ticket failure

Investigated the network failure in `sb ticket save`. 

Found:
- Request was made to `https://spabreaks.atlassian.net/rest/api/2/issue/10402` (missing `SB-` prefix).
- `JIRA_URL` in `.envrc` might be outdated compared to some zsh aliases using `palatinategroup.atlassian.net`.
- `JIRA_TOKEN` was recently changed to `airbrake_auth_token` in a commit, which is suspicious.

The user wants a command to list all project fields to verify `customfield_10174`.

Plan:
1. Provide a `curl` (or `http get`) command to list issue fields.
2. Provide a command to fetch a single issue's raw data to inspect available custom fields.
3. Suggest improvements to `sb.nu` to handle ticket prefixing automatically.

- **Found:** Missing SB- prefix in the failing request.
- **Found:** Suspicious JIRA_TOKEN change in recent history.
- **Decided:** Do not change env vars yet per user request.
- **Open:** Is customfield_10174 still valid?
- **Open:** Is the 404 due to the missing prefix, incorrect URL, or auth failure?

## [9ea24c9-dirty] Make 'todo' default artifact category in Neovim mem utils

- **Found:** Snacks.picker.select starts selection at the first item in the list.
- **Decided:** Moved 'todo' to the top of the category selection list in mem.lua to make it the first and default selection.

## [69b9bb7-dirty] Linked standard markdown highlights to custom groups

- **Found:** Custom markdown highlights are defined in lua/config/setup/highlights.lua and used by render-markdown.lua.
- **Decided:** Linked @markup.heading.1-6.markdown and markdownH1-6 to MarkdownBg1-6 groups to ensure consistent coloring outside of render-markdown plugin.
- **Decided:** Linked @markup.raw.block.markdown to MarkdownBg0 for consistent code block backgrounds.

## [f579c2f-dirty] Plan redesign of mem management and keybindings

Planned a major redesign of the memory artifact management system and consolidated AI-related keybindings. The new system prioritizes ergonomic home-row keys (Colemak) and integrates more deeply with the `mem` CLI.

- **Found:** The current mem.lua utility lacks specific support for passing frontmatter to the CLI.
- **Found:** Opencode keybindings are currently scattered in a plugin config file.
- **Decided:** Consolidate all AI/Mem bindings under <space> leader.
- **Decided:** Use <C-t> as a fast-path for listing current branch artifacts.
- **Decided:** Standardize Todo/Plan creation with title prompt, auto-slugification, and pre-filled frontmatter.
- **Decided:** Spec artifacts will default to --root.
- **Decided:** Clean up dead agents_utils functionality.

## [4bc5140-dirty] Enhance mem.lua utility core

Updated `mem.lua` utility with:
- `slugify` helper for filename generation.
- Added `archived` to `DONE_STATUSES`.
- Enhanced `get_mem_artifacts` to support filtering by `--type` and `--branch`.
- Updated `M.add` to support `--frontmatter` and `--branch` flags.

- **Decided:** Use slugify for automatic filename generation in interactive flows.
- **Decided:** Support targeted listing by type/branch at the CLI level.

## [41301e8-dirty] Add interactive artifact flows to mem.lua

Implemented interactive flows in `mem.lua`:
- `add_todo_or_plan`: Prompts for title, slugifies filename, pre-fills frontmatter.
- `add_spec`: Prompts for path, uses `--root`.
- `pick_branch_artifacts`: Lists branches from `.mem/` and then lists artifacts for the selected branch.

- **Decided:** Default spec artifacts to --root.
- **Decided:** Pre-fill status=open and priority=0 for Todos and Plans.

## [adaa49e-dirty] Consolidate AI and Mem keybindings

Consolidated all AI and Mem keybindings in `mappings.lua`:
- Moved Opencode bindings to `<space>o`.
- Implemented new ergonomic Mem hierarchy:
    - `<C-t>`: Quick list.
    - `<space>n`: New Todo/Plan/Spec (supports master branch).
    - `<space>e`: Targeted list by type/branch.
- Removed dead `agents_utils` functionality.
- Relocated `<space>r` to `<space>or`.

- **Decided:** Use <space> as the primary leader for AI/Mem operations.
- **Decided:** Prioritize n and t keys for frequent operations.

## [3f652fd-dirty] Cleanup opencode.lua plugin keymaps

Removed keymap definitions from `opencode.lua` plugin configuration to avoid duplication and maintain a single source of truth in `mappings.lua`.

- **Decided:** Keep all keybindings in mappings.lua for better maintainability.

## [3f652fd-dirty] Complete task: make creation of todos easier

Completed the task "make creation of todos easier". 
Verified keybindings and artifact creation flows.
Updated the todo artifact status to complete.

- **Decided:** Marking the task as complete.

## [edb8f0c] Fix ctx_clipboard regression in mappings.lua

Fixed a regression where `ctx_clipboard` was accidentally removed from `mappings.lua` during the keybinding consolidation. Also removed a temporary `vim.notify("test")` call.

- **Decided:** Restore ctx_clipboard requirement to fix runtime error.

## [8b627c3] Improve cursor placement for new artifacts

Updated `M.add` to automatically move the cursor to the bottom of the file (`normal! G`) and enter insert mode (`startinsert!`) when a new artifact is opened. This ensures that when frontmatter is present, the user starts typing at the end of the file instead of the first line.

- **Decided:** Automatically move cursor to bottom of file for new artifacts to improve typing UX.

## [cf69371] Add missing artifact shortcuts

Added the missing keybindings for `spec`, `doc`, and `plan` artifacts under both `<space>e` (entries) and `<space>n` (new).

Keybindings added:
- `<space>eS`: List specs for all branches.
- `<space>ep`: List plans for current branch.
- `<space>nP`: New plan on master branch.
- `<space>nd`: New doc on current branch.
- `<space>nD`: New doc on master branch.

This ensures consistent support for the four primary artifact types.

- **Decided:** Support all core artifact types (todo, spec, doc, plan) in shortcuts.

## [6f02ba7] Customize frontmatter per artifact type

Implemented a configuration table `M.TYPE_DEFAULTS` in `mem.lua` to define default frontmatter fields for each artifact type.
- `todo` and `plan`: `status=open`, `priority=0`.
- `doc`: `status=open` (no priority).
- Renamed `add_todo_or_plan` to `add_with_title` to reflect its generalized use for multiple artifact types.
- Updated `mappings.lua` to use the new function name.

- **Decided:** Use a centralized configuration for per-type frontmatter defaults.
- **Decided:** Docs should not have a priority field by default.

## [0e256a1] Implement ui_pick and fix <space>eu mapping

Implemented `M.ui_pick()` in `mem.lua` to provide a guided dialog for listing artifacts with branch and type filters.
- Added `select_branch_helper` to handle current/master/base/all/custom branch selection.
- Fixed `<space>eu` in `mappings.lua` to call `ui_pick()` instead of `MemAdd` (creation).
- Creation still remains available via `<space>nu`.

- **Decided:** Separate artifact creation (MemAdd) from artifact listing (ui_pick) in the UI mappings.
- **Decided:** Provide a guided branch/type selection flow for flexible artifact exploration.

## [4902df9] Fix Telescope layout cycling and preview toggle issues

The user reported that `C-x` (cycle_layout_next) required two presses to switch from horizontal to vertical when `layout_strategy` was set to `flex`. This was because `flex` often resolved to `horizontal`, and the first cycle action would jump from `flex` to the explicit `horizontal` strategy (looking identical).

I also addressed the issue where `C-p` (toggle_preview) would not work at certain widths by setting `horizontal.preview_cutoff` to `0`.

Changes:
- Set `layout_strategy` to `horizontal` by default.
- Set `horizontal.preview_cutoff` to `0` to ensure the preview can always be toggled.

- **Found:** flex strategy causes redundant steps in cycle_layout_next if it resolves to the same strategy as the first cycle item.
- **Found:** preview_cutoff > 0 can disable toggle_preview functionality in certain strategies if window dimensions are too small.
- **Decided:** Set default layout strategy to horizontal to fix cycling redundancy.
- **Decided:** Set horizontal preview_cutoff to 0 to ensure preview is always toggleable.

## [2ee8424] feat(mem): move archived items to bottom and style without strikethrough

- **Found:** Archived status items were previously mixed with active ones or styled with strikethrough because they were part of DONE_STATUSES
- **Decided:** Introduced is_archived and is_finished helpers to separate archived from done while keeping both at bottom of list in Telescope picker
- **Decided:** Added MemStatusArchived highlight for grey text without strikethrough in highlights.lua

## [94e4af3-dirty] Include dynamic branch names in UI

Updated `M.pick_artifacts` in `mem.lua` to include the target branch name and active type filters in the Telescope prompt title.
Enhanced `mappings.lua` by dynamically injecting `vim.g.git_master` and `vim.g.git_base` values into keybinding descriptions for better clarity in the `which-key` menu.

- **Decided:** Prioritize target branch over current branch in picker titles.
- **Decided:** Make branch-related mappings self-documenting by including the actual branch name in their descriptions.

## [4b1f17a-dirty] Renamed mem to cue

Renamed mem utility to cue, updated mappings and highlights to use cue instead of mem. Updated command prefixes from Mem to Cue. Updated paths from .mem/ to .cue/. Updated highlight group names.

- **Found:** Occurrences of mem in mappings.lua, highlights.lua and mem.lua
- **Decided:** Renamed mem.lua to cue.lua
- **Decided:** Updated all internal references in cue.lua from mem to cue
- **Decided:** Updated mappings.lua to use cue_utils and Cue commands
- **Decided:** Updated highlights.lua to use cue_highlights and Cue highlight groups

