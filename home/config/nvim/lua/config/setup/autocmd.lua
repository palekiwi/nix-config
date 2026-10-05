local create_autocmd = vim.api.nvim_create_autocmd

local function update_gitsigns_base()
  create_autocmd("VimEnter", {
    callback = function()
      -- anchor to the merge-base of the remote-resolved base so hunks
      -- show this branch's changes, not stale-base noise
      local base = require('config.utils.helpers.git').diff_base()
      require("gitsigns").change_base(base, true)
    end,
  })
end

return function()
  update_gitsigns_base()

  create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*/files/*.yml", "*/k8s/*.yml" },
    command = "setlocal filetype=yaml",
  })

  -- create_autocmd({ "BufRead" }, {
  --   pattern = { "*" },
  --   command = "set foldlevel=99",
  -- })

  create_autocmd("VimEnter", {
    callback = function()
      --- if launched in a rails project directory
      if vim.fn.filereadable("bin/rails") == 1 then
        --- mappings only for a rails project
        require("config.keymaps.rails")
      end
    end,
  })

  create_autocmd("User", {
    pattern = "TelescopePreviewerLoaded",
    callback = function(_args)
      vim.wo.wrap = false
    end,
  })
end
