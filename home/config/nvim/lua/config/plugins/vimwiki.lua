return {
  {
    "serenevoid/kiwi.nvim",
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
