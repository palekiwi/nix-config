M = {}

---@return string
local function get_file_name()
  local file_name = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
  assert(file_name ~= "", "Not a valid file.")

  return file_name
end

---@param command string
---@return string
local function run_command(command)
  local handle = assert(io.popen(command))
  local result = handle:read("*a")
  handle:close()

  return result
end

-- get the name and name of current repo
local function get_repo()
  local repo_out = run_command("git remote -v 2>/dev/null")
  assert(repo_out ~= "", "Not a git repository or no remote set.")

  local repo = string.match(repo_out, "github%.com.([^ ]+)")
  assert(repo, "Remote not hosted on GitHub")

  return string.gsub(repo, ".git", "")
end

local function get_hash()
  return run_command("git log -n 1 --pretty=format:'%H'")
end

---@param file_name string
---@param line_number number
---@return string
local function get_hash_from_blame(file_name, line_number)
  local output = run_command("git blame -L " .. line_number .. ",+1 -l " .. file_name)

  return string.match(output, "%^?([^ ]+)")
end

---@param file_name string
---@return string | nil
local function get_file_hash(file_name)
  local file_hash_out = run_command("echo -n " .. file_name .. " | sha256sum")

  return string.match(file_hash_out, "%w+")
end

-- builds and copies to system clipboard a URL pointing to
-- the currently open buffer and line number under cursor on github.com
M.copy_file_url = function(opts)
  local repo = get_repo()
  local file_name = get_file_name()

  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local hash = opts and opts.branch or get_hash()

  local url = "https://github.com/" .. repo .. "/blob/" .. hash .. "/" .. file_name .. "#L" .. line_number

  vim.fn.setreg("+", url)

  vim.notify("Copied file URL to clipboard.")
end

-- builds and copies to system clipboard a URL pointing to
-- the most recent commit that modified the line under cursor on github.com
M.copy_diff_url = function()
  local repo = get_repo()
  local file_name = get_file_name()

  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local hash = get_hash_from_blame(file_name, line_number)
  vim.notify(hash)
  local file_hash = get_file_hash(file_name)

  local url = "https://github.com/" .. repo .. "/commit/" .. hash .. "/#diff-" .. file_hash .. "R" .. line_number

  vim.fn.setreg("+", url)

  vim.notify("Copied diff URL to clipboard.")
end

---@param hash string
M.copy_commit_url = function(hash)
  local repo = get_repo()

  local url = "https://github.com/" .. repo .. "/commit/" .. hash

  vim.fn.setreg("+", url)

  vim.notify("Copied commit URL to clipboard.")
end

---@param str string
M.copy_pr_url_from_string = function(str)
  local repo = get_repo()
  local pr_number = str:match("#(%d+)")

  if pr_number then
    local url = "https://github.com/" .. repo .. "/pull/" .. pr_number ---@type string
    vim.fn.setreg("+", url)
    vim.notify(string.format("Copied url for PR #%s to clipboard", pr_number))
  else
    vim.notify("No PR number in the message")
  end
end

M.copy_blame_hash_short = function()
  local file_name = get_file_name()

  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local hash = get_hash_from_blame(file_name, line_number):sub(1, 7)

  vim.fn.setreg("+", hash)

  vim.notify("Copied commit hash to clipboard: " .. hash)
end

M.copy_files_changed_url = function()
  local pr_number = vim.g.gh_pr_number
  if not pr_number then
    return
  end

  local repo = get_repo()
  local file_name = get_file_name()

  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local file_hash = get_file_hash(file_name)

  local url = "https://github.com/" .. repo .. "/pull/" .. pr_number .. "/files#diff-" .. file_hash .. "R" .. line_number

  vim.fn.setreg("+", url)

  vim.notify("Copied files changed URL to clipboard.")
end

---@param first_hash string
---@param second_hash string
M.copy_commit_compare_url = function(first_hash, second_hash)
  local repo = get_repo()

  local url = "https://github.com/" .. repo .. "/compare/" .. first_hash .. "..." .. second_hash

  vim.fn.setreg("+", url)

  vim.notify("Copied commit compare URL to clipboard.")
end

return M
