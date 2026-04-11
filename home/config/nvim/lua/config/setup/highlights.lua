local function stimulus_hightlights()
  local color = vim.api.nvim_get_hl(0, { name = 'Constant' })
  vim.api.nvim_set_hl(0, "@stimulus-controller.html", { fg = color.fg, bold = true })
  vim.api.nvim_set_hl(0, "@stimulus-attribute.html", { fg = color.fg, bold = false })
end

local function lsp_highlights()
  local color = vim.api.nvim_get_hl(0, { name = "Comment" })
  vim.api.nvim_set_hl(0, "LspInlayHint", { fg = color.fg, bg = "none", italic = true })
end

return function()
  stimulus_hightlights()
  lsp_highlights()
end
