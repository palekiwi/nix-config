local function stimulus_hightlights()
  local color = vim.api.nvim_get_hl(0, { name = 'Constant' })
  vim.api.nvim_set_hl(0, "@stimulus-controller.html", { fg = color.fg, bold = true })
  vim.api.nvim_set_hl(0, "@stimulus-attribute.html", { fg = color.fg, bold = false })
end

local function lsp_highlights()
  local color = vim.api.nvim_get_hl(0, { name = "Comment" })
  vim.api.nvim_set_hl(0, "LspInlayHint", { fg = color.fg, bg = "none", italic = true })
end

local function markdown_highlights()
  vim.api.nvim_set_hl(0, "MyCustomMarkdownBg", { bg = "#101010" })
  vim.api.nvim_set_hl(0, "MyCustomMarkdownBg2", { bg = "#161B22" })
end

local function mem_highlights()
  vim.api.nvim_set_hl(0, "MemCategorySpec", { fg = "#ff7b72", bold = false })  -- pink
  vim.api.nvim_set_hl(0, "MemCategoryPlan", { fg = "#bc8cff", bold = false })  -- purple
  vim.api.nvim_set_hl(0, "MemCategoryTodo", { fg = "#58a6ff", bold = false })  -- blue
  vim.api.nvim_set_hl(0, "MemCategoryDoc", { fg = "#d29922", bold = false })   -- orange
  vim.api.nvim_set_hl(0, "MemCategoryTrace", { fg = "#39c5cf", bold = false }) -- cyan
  vim.api.nvim_set_hl(0, "MemCategoryBin", { fg = "#f85149", bold = false })   -- red
  vim.api.nvim_set_hl(0, "MemCategoryTmp", { fg = "#4C566A", bold = false })   -- grey
  vim.api.nvim_set_hl(0, "MemCategoryRef", { fg = "#4C566A", bold = false })   -- grey
end

return function()
  stimulus_hightlights()
  lsp_highlights()
  markdown_highlights()
  mem_highlights()
end
