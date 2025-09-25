return {
  {
      "someone-stole-my-name/yaml-companion.nvim",
      enabled = true,
      dependencies = {
        "neovim/nvim-lspconfig",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
      },
    config = function()
      require("telescope").load_extension("yaml_schema")
      require("yaml-companion").setup({})
      --- require("lspconfig")["yamlls"].setup(cfg)
    end,
  }
}
