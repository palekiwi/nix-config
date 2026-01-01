-- Only apply to _spec.rb files
if not vim.fn.expand("%"):match("_spec%.rb$") then
  return
end

local ts_utils = require("nvim-treesitter.ts_utils")

local M = {
    -- define the query to match RSpec blocks: describe, context, it
    query = vim.treesitter.query.parse("ruby", [[
      (call
        method: (identifier) @method
        (#match? @method "^(describe|context|it)$")
      ) @rspec_block
    ]]),
}

M.init = function()
    -- search the current buffer
    M.buffer = 0

    -- references to lines within the buffer
    M.first_line = 0
    M.current_line = vim.fn.line(".")
    M.previous_line = M.current_line - 1
    M.next_line = M.current_line + 1
    M.last_line = -1

    -- default count
    M.count = 1

    if vim.v.count > 1 then
        M.count = vim.v.count
    end

    -- list of captures
    M.captures = {}

    -- get the parser
    M.parser = vim.treesitter.get_parser()
    -- parse the tree
    M.tree = M.parser:parse()[1]
    -- get the root of the resulting tree
    M.root = M.tree:root()
end

M.next_block = function()
    M.init()

    -- populate captures with all matching nodes from the next line to
    -- the last line of the buffer, but only keep nodes that start after current line
    for _, node, _, _ in
        M.query:iter_captures(M.root, M.buffer, M.next_line, M.last_line)
    do
        local start_row, _, _, _ = node:range()
        -- Only include nodes that start at or after the next line (0-indexed row vs 1-indexed line)
        if start_row >= M.current_line then
            table.insert(M.captures, node)
        end
    end

    -- get the node at the specified index
    ts_utils.goto_node(M.captures[M.count])
end

M.previous_block = function()
    M.init()

    -- if we are already at the top of the buffer
    -- there are no previous blocks
    if M.current_line == M.first_line + 1 then
        return
    end

    -- populate captures with all matching nodes from the first line
    -- of the buffer to the previous line
    for _, node, _, _ in
        M.query:iter_captures(M.root, M.buffer, M.first_line, M.previous_line)
    do
        table.insert(M.captures, node)
    end

    -- get the node at the specified index
    ts_utils.goto_node(M.captures[#M.captures - M.count + 1])
end

-- Set treesitter folding for RSpec files
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt_local.foldlevel = 1

-- define the keymaps (same as markdown for consistency)
vim.keymap.set({"n", "v"}, "<A-}>", M.next_block, { buffer = true, desc = "Next RSpec block" })
vim.keymap.set({"n", "v"}, "<A-{>", M.previous_block, { buffer = true, desc = "Previous RSpec block" })
