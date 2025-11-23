-- module for agent related tasks

local telescope = require 'telescope.builtin' ---@type table
local git_helpers = require("config.utils.helpers.git")

local M = {}

AGENTS_DIR = ".agents/"

-- create the spec.md file
M.create_spec = function()
  local branch = git_helpers.current_git_branch()
  local path = AGENTS_DIR .. branch .. "/spec.md"

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.cmd.edit(path)
end


-- search in .agents/<branch-name>
M.find_files = function()
  local branch_name = git_helpers.current_git_branch()

  telescope.find_files({ cwd = AGENTS_DIR .. branch_name })
end

return M
