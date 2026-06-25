return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      -- anti_conceal = {
      --   enabled = false,
      -- },
      heading = {
        -- Use your custom group for all heading levels (H1 through H6)
        -- backgrounds = {},
        backgrounds = {
          'MarkdownBg1', 'MarkdownBg2', 'MarkdownBg3',
          'MarkdownBg4', 'MarkdownBg5', 'MarkdownBg6'
        },
      },
      code = {
        -- Apply it to the body of code blocks
        highlight = 'MarkdownBg0',

        -- Apply it to the language header line (triple backticks line)
        highlight_border = 'MarkdownBg0',

        -- Apply it to inline code (backticks)
        highlight_inline = 'NONE',

        -- Ensure background is NOT disabled so your group is applied
        disable_background = false,
      },
    },
  }
}
