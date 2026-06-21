---
status: archived
---
# Plan: Add option to copy relative filepath

The user wants to add an extra option to copy a relative filepath in Neovim mappings.
Currently, absolute file path copying is implemented in `home/config/nvim/lua/config/utils/context_clipboard.lua` and mapped in `home/config/nvim/lua/config/mappings.lua`.

## Proposed Changes

### 1. Update `home/config/nvim/lua/config/utils/context_clipboard.lua`

Modify `M.copy_file_path` to accept a `relative` boolean parameter.

```lua
M.copy_file_path = function(include_cursor, relative)
  local modifier = relative and ':.' or ':p'
  local filepath = vim.fn.fnamemodify(vim.fn.expand('%'), modifier)
  local result = filepath

  if include_cursor then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local col = cursor[2] + 1
    result = string.format("%s L%d:C%d", filepath, line, col)
  end

  vim.fn.setreg('+', result)
  vim.notify(string.format("Copied: %s", result), vim.log.levels.INFO)
end
```

### 2. Update `home/config/nvim/lua/config/mappings.lua`

Add a new mapping for relative file path. I'll add `<leader>yr` to the `y` (Copy to clipboard) group.

```lua
  { "<leader>yr",      function() ctx_clipboard.copy_file_path(false, true) end,                              desc = "Relative file path" },
```

I will also add it after `<leader>yf` for consistency.

## Verification Plan

1. Open a file in Neovim.
2. Press `<leader>yr`.
3. Verify that the relative path is copied to the clipboard.
4. Verify that `<leader>yf` still copies the absolute path.
5. Verify that `<leader>C` still copies the absolute path with cursor position.
