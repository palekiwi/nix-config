return {
  {
    "EdenEast/nightfox.nvim",
    config = function()
      require('nightfox').setup({
        options = {
          transparent = true,
          dim_inactive = false,
          styles = {
            comments = "italic",
          },
        },
        groups = {
          all = {
            NormalFloat = { bg = "NONE" },
            FloatBorder = { bg = "NONE" },
            SnacksNormal = { bg = "NONE" },
            SnacksWinBar = { bg = "NONE" },
          }
        },
      })
      vim.cmd("colorscheme nordfox")
    end
  },
}
