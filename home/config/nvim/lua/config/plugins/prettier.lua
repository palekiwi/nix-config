return {
  {
    "MunifTanjim/prettier.nvim",
    config = function()
      local prettier = require("prettier")
      prettier.setup({
        bin = 'prettier',   --- or `'prettierd'` (v0.22+)
        filetypes = {
          "css",
          "astro",
          "html",
          "javascript",
          "javascriptreact",
          "json",
          "less",
          "markdown",
          "scss",
          "typescript",
          "typescriptreact",
          "yaml",
          "php",
          "vue",
        },
        ["null-ls"] = {
          condition = function()
            return prettier.config_exists({
              -- if `false`, skips checking `package.json` for `"prettier"` key
              check_package_json = true,
            })
          end,
          runtime_condition = function(_params)
            -- return false to skip running prettier
            return true
          end,
          timeout = 5000,
        }
      })
    end,
  }
}
