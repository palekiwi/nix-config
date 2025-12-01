local M = {}

M.last_commit_on_base = function()
  local last_commit_on_base = vim.fn.system({
    "git",
    "merge-base",
    "HEAD",
    vim.g.git_base or vim.g.git_master or "master"
  })

  assert(vim.v.shell_error == 0, last_commit_on_base)

  return vim.trim(last_commit_on_base)
end

M.current_git_branch = function()
  local current_branch = vim.fn.system({
    "git",
    "rev-parse",
    "--abbrev-ref",
    "HEAD"
  })

  assert(vim.v.shell_error == 0, current_branch)

  return vim.trim(current_branch)
end

M.current_git_commit = function(short)
  local args = {"git", "rev-parse"}
  if short then
    table.insert(args, "--short")
  end
  table.insert(args, "HEAD")

  local current_commit = vim.fn.system(args)

  assert(vim.v.shell_error == 0, current_commit)

  return vim.trim(current_commit)
end

return M
