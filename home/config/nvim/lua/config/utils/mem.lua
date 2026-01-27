local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local entry_display = require('telescope.pickers.entry_display')
local make_entry = require('telescope.make_entry')
local utils = require('telescope.utils')

local M = {}

-- Execute shell command and return result
local function execute_command(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil, "Failed to execute command"
  end

  local result = handle:read("*a")
  local success = handle:close()

  if not success then
    return nil, "Command failed"
  end

  return result
end

-- Parse JSON using vim's json_decode
local function parse_json(json_str)
  local ok, result = pcall(vim.fn.json_decode, json_str)
  if not ok then
    return nil, "Failed to parse JSON"
  end
  return result
end

-- Get current git branch
local function get_current_branch()
  local result = vim.fn.system('git rev-parse --abbrev-ref HEAD 2>/dev/null')
  if vim.v.shell_error == 0 then
    return result:gsub("%s+", "")
  end
  return nil
end

-- Get artifact list from mem CLI
local function get_mem_artifacts(all_branches, include_ignored)
  -- Check if mem command exists
  vim.fn.system('which mem 2>/dev/null')
  if vim.v.shell_error ~= 0 then
    vim.notify("Error: 'mem' command not found. Please ensure it's installed and in your PATH.", vim.log.levels.ERROR)
    return nil
  end

  -- Build command
  local cmd = 'mem list --json'
  if all_branches then
    cmd = cmd .. ' --all'
  end
  if include_ignored then
    cmd = cmd .. ' --include-ignored'
  end
  cmd = cmd .. ' 2>/dev/null'

  -- Execute command
  local output, err = execute_command(cmd)
  if not output or output == "" then
    if err then
      vim.notify("Error fetching mem artifacts: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("No mem artifacts found", vim.log.levels.INFO)
    end
    return nil
  end

  -- Parse JSON
  local artifacts, parse_err = parse_json(output)
  if not artifacts then
    vim.notify("Error parsing mem data: " .. (parse_err or "unknown"), vim.log.levels.ERROR)
    return nil
  end

  return artifacts
end

-- Format category badge for display
local function format_category(category)
  return string.format("[%s]", string.upper(category))
end

-- Get highlight group for category
local function get_category_highlight(category)
  local highlights = {
    trace = "TelescopeResultsIdentifier",
    root = "TelescopeResultsFunction",
    tmp = "TelescopeResultsVariable",
    ref = "TelescopeResultsConstant",
  }
  return highlights[category] or "TelescopeResultsNormal"
end

-- Custom entry maker for mem artifacts
local function make_mem_entry_maker(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },           -- category badge
      { width = 45 },          -- filename
      { width = 12 },          -- hash (full short hash)
      { remaining = true },    -- branch (use remaining space)
    },
  }

  local make_display = function(entry)
    -- Handle vim.NIL from JSON null values
    local hash_display = "" ---@type string
    if entry.hash and entry.hash ~= vim.NIL then
      hash_display = entry.hash ---@type string
    end

    -- Truncate filename to 45 characters
    local display_name = utils.transform_path(opts, entry.name)
    if #display_name > 45 then
      display_name = display_name:sub(1, 42) .. "..." ---@type string
    end

    return displayer {
      { format_category(entry.category), get_category_highlight(entry.category) },
      { display_name, "TelescopeResultsNormal" },
      { hash_display, "TelescopeResultsComment" },
      { entry.branch, "TelescopePreviewDate" },
    }
  end

  return function(entry)
    if not entry or not entry.path then
      return nil
    end

    -- Build ordinal for fuzzy matching
    -- Handle vim.NIL from JSON null values
    local hash_for_search = "" ---@type string
    if entry.hash and entry.hash ~= vim.NIL then
      hash_for_search = entry.hash ---@type string
    end

    local ordinal = string.format("%s %s %s %s",
      entry.name,
      hash_for_search,
      entry.branch,
      entry.category
    )

    return make_entry.set_default_entry_mt({
      value = entry, ---@type table
      display = make_display, ---@type function
      ordinal = ordinal, ---@type string
      path = entry.path, ---@type string
      category = entry.category, ---@type string
      hash = entry.hash, ---@type string?
      name = entry.name, ---@type string
      branch = entry.branch, ---@type string
      commit_timestamp = entry.commit_timestamp, ---@type number?
      commit_hash = entry.commit_hash, ---@type string?
    }, opts)
  end
end

-- Sort artifacts: current branch first, then by category, then by name
local function sort_artifacts(artifacts)
  local current_branch = get_current_branch()

  -- Category priority mapping
  local category_priority = {
    root = 1,
    trace = 2,
    tmp = 3,
    ref = 4,
  }

  ---@param a table
  ---@param b table
  ---@return boolean
  table.sort(artifacts, function(a, b)
    -- First: current branch comes first
    local a_is_current = a.branch == current_branch ---@type boolean
    local b_is_current = b.branch == current_branch ---@type boolean
    if a_is_current ~= b_is_current then
      return a_is_current
    end

    -- Second: category priority
    local a_priority = category_priority[a.category] or 999 ---@type number
    local b_priority = category_priority[b.category] or 999 ---@type number
    if a_priority ~= b_priority then
      return a_priority < b_priority
    end

    -- Third: commit_timestamp (most recent first)
    local a_timestamp = a.commit_timestamp and a.commit_timestamp ~= vim.NIL and a.commit_timestamp or 0 ---@type number
    local b_timestamp = b.commit_timestamp and b.commit_timestamp ~= vim.NIL and b.commit_timestamp or 0 ---@type number
    if a_timestamp ~= b_timestamp then
      return a_timestamp > b_timestamp
    end

    -- Fourth: alphabetically by name
    return a.name < b.name
  end)

  return artifacts
end

-- Main picker function
function M.pick_artifacts(opts)
  opts = opts or {}

  local artifacts = get_mem_artifacts(opts.all, not opts.all)
  if not artifacts or #artifacts == 0 then
    return
  end

  -- Sort artifacts
  artifacts = sort_artifacts(artifacts) ---@type table

  -- Build prompt title
  local prompt_title = "Mem Artifacts"
  if opts.all then
    prompt_title = prompt_title .. " (All Branches)"
  else
    local branch = get_current_branch()
    if branch then
      prompt_title = prompt_title .. " (" .. branch .. ")"
    end
  end

  local picker_opts = {
    prompt_title = prompt_title, ---@type string
    finder = finders.new_table({
      results = artifacts, ---@type table
      entry_maker = make_mem_entry_maker(opts),
    }),
    sorter = conf.generic_sorter({}), ---@type table
    previewer = conf.file_previewer({}), ---@type table
    layout_strategy = "vertical",
    layout_config = {
      vertical = {
        preview_cutoff = 0,
        preview_height = 0.4,
      },
    },
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local entry = action_state.get_selected_entry() ---@type table
        if entry then
          vim.cmd.edit(entry.path)
        end
      end)

      -- Copy path to clipboard
      map('i', '<C-y>', function()
        local entry = action_state.get_selected_entry() ---@type table
        if entry then
          vim.fn.setreg('+', entry.path)
          vim.notify("Copied path: " .. entry.path, vim.log.levels.INFO)
        end
      end)

      map('n', '<C-y>', function()
        local entry = action_state.get_selected_entry() ---@type table
        if entry then
          vim.fn.setreg('+', entry.path)
          vim.notify("Copied path: " .. entry.path, vim.log.levels.INFO)
        end
      end)

      return true
    end,
  }

  pickers.new({}, picker_opts):find()
end

-- Add a new artifact file using mem add command and open it for editing
function M.add(filename, opts)
  opts = opts or {}

  -- Validate filename
  if not filename or filename == "" then
    vim.notify("Error: filename is required", vim.log.levels.ERROR)
    return nil
  end

  -- Build base command
  local cmd = "mem add " .. vim.fn.shellescape(filename)

  -- Add category flag
  if opts.category == "trace" then
    cmd = cmd .. " --trace"
  elseif opts.category == "tmp" then
    cmd = cmd .. " --tmp"
  elseif opts.category == "ref" then
    cmd = cmd .. " --ref"
  end

  -- Add commit hash if provided and category allows it
  if opts.commit and (opts.category == "trace" or opts.category == "tmp") then
    cmd = cmd .. " --commit " .. vim.fn.shellescape(opts.commit)
  end

  -- Add force flag
  if opts.force then
    cmd = cmd .. " --force"
  end

  -- Execute command
  local output, err = execute_command(cmd)
  if not output then
    vim.notify("Error adding file: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return nil
  end

  -- Parse output to get relative path
  local filepath = output:gsub("%s+", "") ---@type string
  if filepath == "" then
    vim.notify("Error: failed to get file path from mem add output", vim.log.levels.ERROR)
    return nil
  end

  -- Open the file in a new buffer
  vim.cmd.edit(filepath)

  return filepath
end

return M
