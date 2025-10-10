local create_autocmd = vim.api.nvim_create_autocmd

local function update_gitsigns_base()
  create_autocmd("VimEnter", {
    callback = function()
      local base_branch = vim.g.git_base or vim.g.git_master or "master"
      require("gitsigns").change_base(base_branch, true)
    end,
  })
end

return function()
  update_gitsigns_base()

  create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*/files/*.yml", "*/k8s/*.yml" },
    command = "setlocal filetype=yaml",
  })

  create_autocmd({ "BufRead" }, {
    pattern = { "*" },
    command = "set foldlevel=99",
  })

  create_autocmd("VimEnter", {
    callback = function()
      --- if launched in a rails project directory
      if vim.fn.filereadable("bin/rails") == 1 then
        --- mappings only for a rails project
        require("config.keymaps.rails")
      end
    end,
  })

end
