local function get_git_base()
  local git_base = vim.g.git_base
  if git_base then
    if git_base:len() > 7 then
      return git_base:sub(1, 7) .. "..."
    else
      return git_base
    end
  else
    return "HEAD"
  end
end

return {
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require 'lualine'.setup {
        options = {
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        },
        sections = {
          lualine_a = { get_git_base },
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {'grapple', 'filename'},
        },
      }
    end,
  }
}
