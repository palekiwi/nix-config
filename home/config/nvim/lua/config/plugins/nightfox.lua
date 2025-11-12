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
      })
      vim.cmd("colorscheme nordfox")
    end
  },
}
