local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set(
  "n",
  "<leader>a",
  function()
    vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
    -- or vim.lsp.buf.codeAction() if you don't want grouping.
  end,
  { silent = true, buffer = bufnr }
)

vim.keymap.set(
  "n",
  "<C-space>", -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp({ 'hover', 'actions' })
  end,
  { silent = true, buffer = bufnr }
)

vim.keymap.set("n", "<leader>ff", function() vim.lsp.buf.format { async = true } end,
  { buffer = bufnr, desc = "[LSP] format" })
vim.keymap.set("n", "<leader>dr", vim.lsp.buf.rename, { buffer = bufnr, desc = "[LSP] rename" })
vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, { buffer = bufnr, desc = "[Diagnostic] next" })
vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, { buffer = bufnr, desc = "[Diagnostic] prev" })
vim.keymap.set("n", "<leader>df", vim.diagnostic.open_float, { buffer = bufnr, desc = "[Diagnostic] float" })
