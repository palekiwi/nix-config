M = {}

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

return M
