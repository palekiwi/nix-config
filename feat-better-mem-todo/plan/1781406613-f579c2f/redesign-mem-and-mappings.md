---
status: complete
---

# Plan: Better Mem Artifact Management and Keybinding Consolidation

## 1. Cleanup

### Dead Code Removal

- Remove `agents_utils` requirement and all associated mappings from `home/config/nvim/lua/config/mappings.lua`.
- Remove legacy `Alt` and `<leader><leader>` mappings for `mem` and agents.

### Opencode Consolidation

- Move all keybindings from `home/config/nvim/lua/config/plugins/opencode.lua` into `home/config/nvim/lua/config/mappings.lua` under the `<space>o` prefix.
- Relocate `<space>r` (File Review) to `<space>or`.

## 2. `mem.lua` Utility Enhancements (`home/config/nvim/lua/config/utils/mem.lua`)

### New Helpers

- **`slugify(text)`**: Converts "My New Task" to "my-new-task.md".
- **`DONE_STATUSES`**: Add `archived = true`.

### CLI Wrapper Updates

- **`M.add(filename, opts)`**:
  - Support `opts.frontmatter` (table of key-value pairs).
  - Support `opts.branch`.
  - Construct `mem add` command with repeatable `--frontmatter` flags.
- **`get_mem_artifacts(all_branches, include_gitignored, filters)`**:
  - Support filtering by `--type` and `--branch` at the CLI level.

### Interactive Flows

- **`M.add_todo_or_plan(type, branch)`**:
  1. Prompt for **Title**.
  2. Slugify for filename.
  3. Pre-fill frontmatter: `status=open`, `priority=0`, `title=<Title>`.
  4. Call `M.add` and open the buffer.
- **`M.add_spec(branch)`**:
  1. Prompt for **Path**.
  2. Call `M.add` with `--type spec` and `--root`.
- **`M.pick_branch_artifacts()`**:
  1. List branches in `.mem/`.
  2. Show picker to select branch.
  3. List artifacts for selected branch.

## 3. New Keybinding System (`mappings.lua`)

Using ergonomic home-row keys (Colemak: `n`, `t`, `e`, `s`, `i`, `r`).

### Top Level

- `<C-t>`: `mem_utils.pick_artifacts()` (List current branch)

### `<space>n` (New Entry)

- `t`: New Todo (current)
- `T`: New Todo (master)
- `p`: New Plan (current)
- `s`: New Spec (current, root)
- `S`: New Spec (master, root)
- `u`: UI guided creation

### `<space>e` (Entries/List)

- `t`: List Todos (current)
- `T`: List Todos (all branches)
- `s`: List Specs (current)
- `d`: List Docs (current)
- `b`: List artifacts for **base branch** (`vim.g.git_base`)
- `B`: Select branch then list artifacts
- `u`: UI guided listing

### `<space>o` (Opencode)

- `a`: Ask
- `i`: Ask this
- `f`: Ask buffer
- `d`: Ask diff
- `n`: New session
- `e`: Cycle agent
- `s`: Select prompt
- `y`: Copy last message
- `r`: File review (moved from `<space>r`)
- `p...`: PR operations
- `+...`: Context operations
