local missing = {}

local function run_helper(name)
  if vim.fn.executable(name) == 0 then
    table.insert(missing, name)
    return ""
  end

  local handle = io.popen(name)
  if not handle then
    return ""
  end
  local result = handle:read("*a"):gsub("%s+", "")
  handle:close()

  return result
end

local function set_master_branch_name()
  local result = run_helper("get_master_branch_name")
  vim.g.git_master = result ~= "" and result or "master"
end

local function set_git_base()
  local result = run_helper("get_pr_base")
  vim.g.git_base = result ~= "" and result or vim.g.git_master
end

local function set_pr_number()
  vim.g.gh_pr_number = run_helper("get_pr_number")
end

set_master_branch_name()
set_git_base()
set_pr_number()

if #missing > 0 then
  vim.schedule(function()
    vim.notify(
      "Missing git helpers: " .. table.concat(missing, ", ") .. "; base branch assumed '" .. vim.g.git_base .. "'",
      vim.log.levels.WARN
    )
  end)
end
