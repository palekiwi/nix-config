--- lazy.nvim spec for the local cue.nvim plugin
---
--- The plugin lives in the same nix-config repo under:
---   home/config/nvim/plugins/cue.nvim/
---
--- We resolve the path at runtime relative to stdpath("config") so it works
--- regardless of where nix-config is checked out.

local plugin_path = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/plugins/cue.nvim"

return {
  {
    "cue.nvim",
    dir = plugin_path,
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
    },
    config = function()
      require("cue").setup({})
    end,
  }
}
