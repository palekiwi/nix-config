vim.opt.runtimepath:append("$HOME/.local/share/nvim/lazy/nvim-treesitter")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require 'nvim-treesitter.configs'.setup {
        ensure_installed = {
          "vimdoc",
          "bash",
          "ini",
          "json",
          "yaml",
          "git_config",
          "gitignore",
          "sxhkdrc",
          "c",
          "cmake",
          "rust",
          "toml",
          "lua",
          "python",
          "javascript",
          "typescript",
          "html",
          "css",
          "astro",
          "dockerfile",
          "go",
          "ruby",
          "vue",
          "nu",
          "nix",
        },

        --- Install parsers synchronously (only applied to `ensure_installed`)
        sync_install = false,

        --- Automatically install missing parsers when entering buffer
        auto_install = true,

        parser_install_dir = "$HOME/.local/share/nvim/lazy/nvim-treesitter",

        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      }
    end,
  },
  { "nvim-treesitter/nvim-treesitter-refactor", },
}
