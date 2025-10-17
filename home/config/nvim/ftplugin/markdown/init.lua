local ts_utils = require("nvim-treesitter.ts_utils")

local M = {
    -- define the query
    query = vim.treesitter.query.parse("markdown", "((atx_heading) @header)"),
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

M.next_heading = function()
    M.init()

    -- populate captures with all matching nodes from the next line to
    -- the last line of the buffer
    for _, node, _, _ in
        M.query:iter_captures(M.root, M.buffer, M.next_line, M.last_line)
    do
        table.insert(M.captures, node)
    end

    -- get the node at the specified index
    ts_utils.goto_node(M.captures[M.count])
end

M.previous_heading = function()
    M.init()

    -- if we are already at the top of the buffer
    -- there are no previous headings
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

-- define the keymaps
vim.keymap.set("n", "<A-j>", M.next_heading)

vim.keymap.set("n", "<A-k>", M.previous_heading)
