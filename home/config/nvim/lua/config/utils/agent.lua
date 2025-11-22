-- module for agent related tasks

local git_helpers = require("config.utils.helpers.git")

local M = {}

-- create the spec.md file
M.create_spec = function()
  local branch = git_helpers.current_git_branch()
  local path = ".agents/" .. branch .. "/spec.md"

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.cmd.edit(path)
end

return M
