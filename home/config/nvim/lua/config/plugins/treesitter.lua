return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    init = function()
      -- install parsers not already present
      local wanted = {
        "vimdoc", "bash", "ini", "json", "yaml", "git_config", "gitignore",
        "sxhkdrc", "c", "cmake", "rust", "toml", "lua", "python",
        "javascript", "typescript", "html", "css", "astro", "dockerfile",
        "go", "ruby", "vue", "nu", "nix",
      }
      local installed = require("nvim-treesitter.config").get_installed()
      local missing = vim.iter(wanted)
        :filter(function(p) return not vim.tbl_contains(installed, p) end)
        :totable()
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end

      -- highlighting and indentation via FileType autocmd
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
