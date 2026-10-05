local M = {}

--- Resolve a base ref to the freshest ref available for it.
---
--- Local branch refs (e.g. `master`) only advance when the branch is
--- checked out and pulled, so they routinely lag behind their
--- remote-tracking ref (e.g. `origin/master`). Diffing HEAD against a
--- lagging base reports changes that arrived on the base branch after
--- the feature branch forked -- merged-in noise instead of the branch's
--- own changes.
---
--- When `base` is a plain local branch name and a remote-tracking
--- counterpart exists that is ahead of the local ref, return the
--- remote-tracking ref. Everything else (commit hashes, `HEAD~1`,
--- already-remote refs like `origin/master`) is returned unchanged.
---@param base string
---@return string
M.resolve_base_ref = function(base)
  if not base then
    return base
  end

  -- only plain local branch names have a remote counterpart to upgrade to
  vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", "refs/heads/" .. base })
  if vim.v.shell_error ~= 0 then
    return base
  end

  local remotes = vim.fn.systemlist({ "git", "remote" })
  if vim.v.shell_error ~= 0 then
    return base
  end

  for _, remote in ipairs(remotes) do
    remote = vim.trim(remote)
    local remote_ref = "refs/remotes/" .. remote .. "/" .. base

    vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", remote_ref })
    if vim.v.shell_error == 0 then
      -- keep the local ref when it is ahead of (or equal to) the remote
      vim.fn.system({ "git", "merge-base", "--is-ancestor", remote_ref, "refs/heads/" .. base })
      if vim.v.shell_error == 0 then
        return base
      end

      return remote .. "/" .. base
    end
  end

  return base
end

M.last_commit_on_base = function()
  local base = M.resolve_base_ref(vim.g.git_base or vim.g.git_master or "master")

  local last_commit_on_base = vim.fn.system({
    "git",
    "merge-base",
    "HEAD",
    base
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
