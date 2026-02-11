return {
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup {
        ensure_installed = {
          -- "ansiblels",
          -- "astro",
          "elmls",
          "eslint",
          -- "gopls",
          -- "pyright",
          --"volar",
          "yamlls",
        },
        automatic_installation = false,
      }
    end,
  }
}
