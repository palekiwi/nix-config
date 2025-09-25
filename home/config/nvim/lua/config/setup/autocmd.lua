local create_autocmd = vim.api.nvim_create_autocmd

--- Sets master branch name on startup 
local function set_master_branch_name()
  create_autocmd("VimEnter", {
    callback = function()
      local handle = io.popen("get_master_branch_name")
      local master_branch = "master"
      if handle then
        local result = handle:read("*a"):gsub("%s+", "")  --[[@as string]]
        if result ~= "" then
          master_branch = result
        end
        handle:close()
      end

      vim.g.git_master = master_branch
    end,
  })
end

--- Sets opencode port on startup 
local function set_opencode_port()
  create_autocmd("VimEnter", {
    callback = function()
      local handle = io.popen("generate_port_from_path")
      if handle then
        vim.g.opencode_port = handle:read("*a"):gsub("%s+", "")  --[[@as string]]
        handle:close()
      end
    end,
  })
end

--- Sets git base name on startup 
local function set_git_base()
  create_autocmd("VimEnter", { -- TODO: consider other events to update the value when the branch changes
    callback = function()
      local handle = io.popen("get_pr_base")
      local base_branch = vim.g.git_master or "master" -- fallback
      if handle then
        local result = handle:read("*a"):gsub("%s+", "")  --[[@as string]]
        if result ~= "" then
          base_branch = result
        end
        handle:close()
      end

      vim.g.git_base = base_branch
      require("gitsigns").change_base(base_branch, true)
    end,
  })
end

--- Sets PR number on startup 
local function set_pr_number()
  create_autocmd("VimEnter", {
    callback = function()
      local handle = io.popen("get_pr_number")
      if handle then
        vim.g.gh_pr_number = handle:read("*a"):gsub("%s+", "")  --[[@as string]]
        handle:close()
      end
    end,
  })
end


return function()
  set_opencode_port()
  set_master_branch_name()
  set_git_base()
  set_pr_number()

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
