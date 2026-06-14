COLORS = {
  grey = "#4c566a",
  dark = "#161B22",
  darker = "#101010",
  blue = "#58a6ff",
  cyan = "#39c5cf",
  orange = "#d29922",
  pink = "#ff7b72",
  purple = "#bc8cff",
  red = "#f85149",
}

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
  vim.api.nvim_set_hl(0, "MarkdownBg0", { bg = COLORS.darker })
  vim.api.nvim_set_hl(0, "MarkdownBg1", { bg = COLORS.dark, fg = COLORS.blue, bold = false })
  vim.api.nvim_set_hl(0, "MarkdownBg2", { bg = COLORS.dark, fg = COLORS.orange, bold = false })
  vim.api.nvim_set_hl(0, "MarkdownBg3", { bg = COLORS.dark, fg = COLORS.cyan, bold = false })
  vim.api.nvim_set_hl(0, "MarkdownBg4", { bg = COLORS.dark, fg = COLORS.pink, bold = false, })
  vim.api.nvim_set_hl(0, "MarkdownBg5", { bg = COLORS.dark, fg = COLORS.purple, bold = false })
  vim.api.nvim_set_hl(0, "MarkdownBg6", { bg = COLORS.dark, fg = COLORS.red, bold = false })

  -- Link standard Treesitter and markdown groups to match render-markdown colors
  for i = 1, 6 do
    local target = "MarkdownBg" .. i
    -- Modern Treesitter groups
    vim.api.nvim_set_hl(0, "@markup.heading." .. i .. ".markdown", { link = target })
    -- Legacy/standard markdown syntax groups
    vim.api.nvim_set_hl(0, "markdownH" .. i, { link = target })
    -- Older Treesitter naming fallback
    vim.api.nvim_set_hl(0, "@text.title." .. i .. ".markdown", { link = target })
  end

  -- Match code block background
  vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", { link = "MarkdownBg0" })
end

local function mem_highlights()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment" })
  vim.api.nvim_set_hl(0, "MemStatusDone", { fg = comment.fg, strikethrough = true })

  vim.api.nvim_set_hl(0, "MemCategorySpec", { fg = COLORS.pink, bold = false, }) -- pink
  vim.api.nvim_set_hl(0, "MemCategoryPlan", { fg = COLORS.purple, bold = false })  -- purple
  vim.api.nvim_set_hl(0, "MemCategoryTodo", { fg = COLORS.blue, bold = false })  -- blue
  vim.api.nvim_set_hl(0, "MemCategoryDoc", { fg = COLORS.orange, bold = false })   -- orange
  vim.api.nvim_set_hl(0, "MemCategoryTrace", { fg = COLORS.cyan, bold = false }) -- cyan
  vim.api.nvim_set_hl(0, "MemCategoryBin", { fg = COLORS.red, bold = false })   -- red
  vim.api.nvim_set_hl(0, "MemCategoryTmp", { fg = COLORS.grey, bold = false })   -- grey
  vim.api.nvim_set_hl(0, "MemCategoryRef", { fg = COLORS.grey, bold = false })   -- grey
end

return function()
  stimulus_hightlights()
  lsp_highlights()
  markdown_highlights()
  mem_highlights()
end
