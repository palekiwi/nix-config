-- module for agent related tasks

local telescope = require 'telescope.builtin' ---@type table
local git_helpers = require("config.utils.helpers.git")

local M = {}

AGENTS_DIR = ".agents/"

-- create the spec.md file
M.open_spec = function()
  local branch = git_helpers.current_git_branch()
  local path = AGENTS_DIR .. branch .. "/latest/SPEC.md"

  if vim.fn.filereadable(path) == 0 then
    vim.notify("Spec file does not exist: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(path)
end

-- create directory .agents/<current-branch-name>/<current-commit>/
M.create_commit_dir = function()
  local branch = git_helpers.current_git_branch()
  local commit = git_helpers.current_git_commit(true)
  local path = AGENTS_DIR .. branch .. "/" .. commit

  vim.fn.mkdir(path, "p")
  vim.notify("Created agent directory: " .. path, vim.log.levels.INFO)
  return path
end

-- search in .agents/<branch-name>
M.find_files = function(opts)
  opts = opts or {}
  local branch_name = git_helpers.current_git_branch()
  local telescope_opts = { cwd = AGENTS_DIR .. branch_name, follow = true }

  if opts.docs then
    telescope_opts.cwd = AGENTS_DIR .. "/_docs/internal"
  elseif opts.latest then
    telescope_opts.cwd = AGENTS_DIR .. branch_name .. "/latest"
  end

  telescope.find_files(telescope_opts)
end

return M
