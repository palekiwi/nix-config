return {
  {
    "marcinjahn/gemini-cli.nvim",
    cmd = "Gemini",
    gemini_cmd = "gemini-cli",
    keys = {
      { "<space>g/", "<cmd>Gemini toggle<cr>",   desc = "Toggle Gemini CLI" },
      { "<space>ga", "<cmd>Gemini ask<cr>",      desc = "Ask Gemini",       mode = { "n", "v" } },
      { "<space>gf", "<cmd>Gemini add_file<cr>", desc = "Add File" },

    },
    dependencies = {
      "folke/snacks.nvim",
    },
    config = true,
  }
}
