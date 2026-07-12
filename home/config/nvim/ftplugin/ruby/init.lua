-- RSpec block navigation (describe/context/it), ported from the legacy
-- nvim-treesitter Lua API to native Neovim 0.12 treesitter APIs. The old
-- version depended on `require("nvim-treesitter.ts_utils").goto_node` and
-- the `nvim_treesitter#foldexpr()` autoload function, both removed in the
-- rewritten nvim-treesitter main branch. Everything below uses only the
-- built-in `vim.treesitter` runtime, so there is no plugin dependency.

-- Only apply to _spec.rb files
if not vim.fn.expand("%"):match("_spec%.rb$") then
  return
end

--- Parsed once at load. Matches RSpec block calls: describe, context, it.
local query = vim.treesitter.query.parse("ruby", [[
  (call
    method: (identifier) @method
    (#match? @method "^(describe|context|it)$")
  ) @rspec_block
]])

--- Return the 0-based start row of every RSpec block in the buffer, ascending.
--- Only `call` nodes are collected (the `@method` identifier captures are
--- skipped) so each block appears exactly once.
---@param bufnr integer
---@return integer[]
local function block_rows(bufnr)
  local parser = assert(vim.treesitter.get_parser(bufnr, "ruby"))
  local root = parser:parse()[1]:root()
  local rows = {}
  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    if node:type() == "call" then
      rows[#rows + 1] = (node:start())
    end
  end
  return rows
end

--- Jump to the count-th RSpec block in the given direction, then scroll it to
--- the top of the window (`zt`). No-op if there is no such block.
---@param direction "next" | "prev"
local function jump(direction)
  local count = vim.v.count == 0 and 1 or vim.v.count
  local cur = vim.fn.line(".") - 1 -- current row, 0-based
  local rows = block_rows(0)

  -- `vim.iter` chains make the directional lookup declarative:
  --   next -> first block strictly after cursor
  --   prev -> reverse, then first block strictly before cursor
  local target
  if direction == "next" then
    target = vim.iter(rows):filter(function(r) return r > cur end):nth(count)
  else
    target = vim.iter(rows):rev():filter(function(r) return r < cur end):nth(count)
  end

  if target then
    vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
    vim.cmd("normal! zt")
  end
end

-- Per-RSpec treesitter folding using the native foldexpr (the replacement
-- for the removed `nvim_treesitter#foldexpr()`). foldlevel 99 keeps the file
-- open by default.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

-- `desc` is picked up by which-key-style plugins; `silent` keeps the jump quiet.
vim.keymap.set({ "n", "v" }, "<C-Down>", function() jump("next") end,
  { silent = true, buffer = true, desc = "RSpec: next block" })
vim.keymap.set({ "n", "v" }, "<C-Up>", function() jump("prev") end,
  { silent = true, buffer = true, desc = "RSpec: previous block" })
