-- conform.nvim: async formatting runner. Step one of the null-ls -> conform
-- migration (null-ls is archived/unmaintained). Markdown only for now; other
-- filetypes keep formatting through null-ls until they are moved over.
-- mdformat resolves from the Nix PATH (programs.neovim.extraPackages).
return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      formatters_by_ft = {
        markdown = { "mdformat" },
      },
      -- mdformat defaults to --wrap=keep: it normalizes structure (blank
      -- lines around headings/lists, list markers, trailing whitespace)
      -- without reflowing prose -- wrapping stays the job of the `gw`
      -- operator in ftplugin/markdown/init.lua. Format-on-save stays off
      -- here; non-markdown filetypes keep the null-ls save hook.
      format_on_save = false,
    },
  },
}
