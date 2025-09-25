local gs = require('gitsigns')
local nt = require('neo-tree.command')

M = {}

local function toggle_git_tree(action, toggle)
  nt.execute({
    action = action,
    position = "right",
    toggle = toggle,
    source = "git_status",
    git_base = vim.g.git_base
  })
end

local function set_base_branch(branch)
  local base_branch = branch or vim.g.git_master or "master"

  vim.g.git_base = base_branch

  gs.change_base(base_branch, true)
  toggle_git_tree("show", false)

  vim.notify("Base branch: " .. base_branch)
end

M.set_base_branch = function(branch) set_base_branch(branch) end

M.toggle_git_tree = function(action) toggle_git_tree(action, true) end

M.diffthis = function(vertical) gs.diffthis(nil, { vertical = vertical }) end

M.diffview_this = function(vertical)
  local base = vim.g.git_base or vim.g.git_master or "master"
  vim.cmd("DiffviewOpen " .. base)
end

---@param range boolean
M.diffview_file_history = function(range)
  if range then
    local base = vim.g.git_base or vim.g.git_master or "master"
    vim.cmd("DiffviewFileHistory % --range=" .. base .. "..HEAD")
  else
    vim.cmd("DiffviewFileHistory %")
  end
end

M.prev_hunk = function()
  gs.nav_hunk("prev", { preview = false, wrap = true })
end

M.next_hunk = function()
  gs.nav_hunk("next", { preview = false, wrap = true })
end

M.hunks_to_loclist = function() gs.setqflist("attached", { use_location_list = true, open = true }) end

M.changed_files_to_loclist = function()
  local base_branch = vim.g.git_base or vim.g.git_master or "master"
  local command = "git diff --name-only --diff-filter=d $(git merge-base HEAD " .. base_branch .. " )"

  local list = vim.fn.systemlist(command)

  vim.fn.setloclist(0, {}, 'r', { title = 'Changed files', efm = '%f', lines = list })

  vim.notify("Loclist set to changed files")
end

local function commit_hash_under_cursor()
  local line_num = vim.fn.line('.')
  local filename = vim.fn.expand('%')

  -- Check if we have a valid file
  if filename == '' or filename == '[No Name]' then
    print('Error: No file or unsaved buffer')
    return
  end

  -- Build the git blame command
  local cmd = { 'git', 'blame', filename, '-L', line_num .. ',' .. line_num, '--porcelain' }

  -- Execute the command
  local result = vim.system(cmd, { text = true }):wait()

  if result.code == 0 then
    -- Extract commit hash (first word of first line)
    local hash = result.stdout:match('^(%w+)')
    if hash then
      -- Check if it's the special "0000000..." hash (uncommitted changes)
      if hash:match('^0+$') then
        print('Line not committed yet (working directory changes)')
        return nil
      else
        return hash
      end
    else
      print('Could not extract commit hash')
    end
  else
    -- Handle errors
    local error_msg = result.stderr or 'Unknown error'
    if error_msg:match('not a git repository') then
      print('Error: Not in a git repository')
    elseif error_msg:match('no such path') then
      print('Error: File not tracked by git')
    else
      print('Git blame failed: ' .. error_msg:gsub('\n', ' '))
    end
  end
end

M.diffview_blame = function()
  local hash = commit_hash_under_cursor()
  vim.cmd(string.format("DiffviewOpen %s^!", hash))
end

return M
