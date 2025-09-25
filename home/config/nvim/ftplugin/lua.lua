local bufnr = vim.api.nvim_get_current_buf()
local set = vim.keymap.set

vim.bo.shiftwidth = 2

set("n", "<A-t>", "<cmd>PlenaryBustedFile %<cr>", { buffer = bufnr, desc = "[Plenary] PlenaryBustedFile" })
