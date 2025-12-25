local set = vim.keymap.set
local bufnr = vim.api.nvim_get_current_buf()

set("n", "i", "<cmd>TagToggle *important<cr>", { buffer = bufnr, desc = "[Notmuch] Toggle Important" })
set("n", "t", "<cmd>TagToggle *todo<cr>", { buffer = bufnr, desc = "[Notmuch] Toggle Todo" })
