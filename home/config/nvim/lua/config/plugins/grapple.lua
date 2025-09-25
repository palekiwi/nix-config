return {
  {
    "cbochs/grapple.nvim",
    enabled = true,
    config = function()
      require("telescope").load_extension("grapple")
      require("grapple").setup({ scope = "git_branch", }) -- setting it up in opts did not take effect
    end,
    event = { "BufReadPost", "BufNewFile" },
    cmd = "Grapple",
    keys = {
      { "tt",         "<cmd>Grapple toggle use_cursor=true<cr>",                  desc = "Grapple toggle tag" },
      { "<C-t>",      "<cmd>Telescope grapple tags layout_strategy=vertical<cr>", desc = "[Telescope] Grapple open tags window" },
      { "<leader>fn", "<cmd>Grapple cycle_tags next<cr>",                         desc = "Grapple cycle next tag" },
      { "<leader>fp", "<cmd>Grapple cycle_tags prev<cr>",                         desc = "Grapple cycle previous tag" },
    },
  }, }
