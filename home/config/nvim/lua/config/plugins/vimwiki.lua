return {
  {
    "serenevoid/kiwi.nvim",
    cond = vim.env.NVIM_NO_PERSONAL == nil,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require('kiwi').setup({
        {
          name = "notes",
          path = "/home/pl/Nextcloud/Notes"
        },
      })
    end,
  }
}
