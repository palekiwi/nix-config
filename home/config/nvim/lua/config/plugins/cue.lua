return {
  {
    "palekiwi-labs/cue.nvim",
    branch = "master",
    dev = false,
    dir = vim.uv.fs_stat(vim.fn.expand("~/code/palekiwi-labs/cue.nvim")) and "~/code/palekiwi-labs/cue.nvim" or nil,
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
