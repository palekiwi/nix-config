return {
  {
    "palekiwi-labs/cue.nvim",
    dev = true,
    dir = "~/code/palekiwi-labs/cue.nvim",
    branch = "master",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
    },
    config = function()
      require("cue").setup({})
    end,
  }
}
