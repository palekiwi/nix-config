local lsp_flags = {
  debounce_text_changes = 150,
}

local on_attach = function(_, bufnr)
  -- vim.keymap.set("n", "<C-h>", vim.lsp.buf.signature_help, { buffer = bufnr })
  vim.keymap.set("n", "<C-space>", vim.lsp.buf.hover, { buffer = bufnr })
  vim.keymap.set("n", "<leader>ff", function() vim.lsp.buf.format { async = true } end,
    { buffer = bufnr, desc = "[LSP] format" })
  vim.keymap.set("n", "<leader>dr", vim.lsp.buf.rename, { buffer = bufnr, desc = "[LSP] rename" })
end

return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      --- Add additional capabilities supported by nvim-cmp
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.lsp.config.cssls = {
        capabilities = require('cmp_nvim_lsp').default_capabilities(
          vim.lsp.protocol.make_client_capabilities()
        )
      }

      vim.lsp.config.elmls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      -- vim.lsp.config.eslint = {
      --   on_attach = function(_, bufnr)
      --     vim.api.nvim_create_autocmd("BufWritePre", {
      --       buffer = bufnr,
      --       command = "LspEslintFixAll",
      --     })
      --   end,
      --   capabilities = capabilities,
      --   flags = lsp_flags,
      -- }

      vim.lsp.config.gopls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.lua_ls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.nushell = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.nixd = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
        settings = {
          nixd = {
            nixpkgs = {
              expr = "import <nixpkgs> { }",
            },
            formatting = {
              command = { "nixpkgs-fmt" },
            },
          },
        }
      }

      vim.lsp.config.ruby_lsp = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.stimulus_ls = {
        offset_encoding = "utf-8",
      }

      vim.lsp.config.terraformls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.ts_ls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.config.yamlls = {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = lsp_flags,
      }

      vim.lsp.enable('eslint')
      vim.lsp.enable('lua_ls')
      vim.lsp.enable('nixd')
      vim.lsp.enable('nushell')
      vim.lsp.enable('ruby_lsp')
      vim.lsp.enable('stimulus_ls')
      vim.lsp.enable('terraformls')
      vim.lsp.enable('ts_ls')
    end,
  }
}
