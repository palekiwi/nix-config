local function set_opencode_port()
  local handle = io.popen("generate_port_from_path")
  if handle then
    vim.g.opencode_port = handle:read("*a"):gsub("%s+", "")
    handle:close()
  end
end

local function set_master_branch_name()
  local handle = io.popen("get_master_branch_name")
  local master_branch = "master"
  if handle then
    local result = handle:read("*a"):gsub("%s+", "")
    if result ~= "" then
      master_branch = result
    end
    handle:close()
  end

  vim.g.git_master = master_branch
end

local function set_git_base()
  local handle = io.popen("get_pr_base")
  local base_branch = vim.g.git_master or "master"
  if handle then
    local result = handle:read("*a"):gsub("%s+", "")
    if result ~= "" then
      base_branch = result
    end
    handle:close()
  end

  vim.g.git_base = base_branch
end

local function set_pr_number()
  local handle = io.popen("get_pr_number")
  if handle then
    vim.g.gh_pr_number = handle:read("*a"):gsub("%s+", "")
    handle:close()
  end
end

set_opencode_port()
set_master_branch_name()
set_git_base()
set_pr_number()
