return {
  {
    "palekiwi-labs/cue.nvim",
    branch = "master",
    dev = false,
    dir = "~/code/palekiwi-labs/cue.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
    },
    config = function()
      require("cue").setup({})
      require("config.utils.cue_review").setup()
    end,
  }
}
