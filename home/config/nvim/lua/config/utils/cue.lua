local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local entry_display = require('telescope.pickers.entry_display')
local make_entry = require('telescope.make_entry')
local utils = require('telescope.utils')
local Snacks = require('snacks')

local telescope_actions = require('config.utils.telescope.actions')

local M = {}

local DONE_STATUSES = {
  done = true,
  complete = true,
  closed = true,
}

local function is_done(artifact)
  if not artifact.frontmatter or artifact.frontmatter == vim.NIL then
    return false
  end
  local status = artifact.frontmatter.status
  return status and type(status) == "string" and DONE_STATUSES[status:lower()] or false
end

local function is_archived(artifact)
  if not artifact.frontmatter or artifact.frontmatter == vim.NIL then
    return false
  end
  local status = artifact.frontmatter.status
  return status and type(status) == "string" and status:lower() == "archived" or false
end

local function is_finished(artifact)
  return is_done(artifact) or is_archived(artifact)
end

-- Slugify text for filenames
local function slugify(text)
  if not text then return nil end
  return text:lower()
    :gsub("[%s_]+", "-")
    :gsub("[^%w%-]+", "")
    :gsub("%-+", "-")
    :gsub("^%-+", "")
    :gsub("%-+$", "")
end

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
    local branch = result:gsub("%s+", "")
    return branch:gsub("/", "-")
  end
  return nil
end

-- Get artifact list from cue CLI
local function get_cue_artifacts(opts)
  opts = opts or {}
  -- Check if cue command exists
  vim.fn.system('which cue 2>/dev/null')
  if vim.v.shell_error ~= 0 then
    vim.notify("Error: 'cue' command not found. Please ensure it's installed and in your PATH.", vim.log.levels.ERROR)
    return nil
  end

  -- Build command
  local cmd = 'cue list --json --frontmatter'
  if opts.all then
    cmd = cmd .. ' --all'
  end
  if opts.branch then
    cmd = cmd .. ' --branch ' .. vim.fn.shellescape(opts.branch)
  end
  if opts.type then
    cmd = cmd .. ' --type ' .. vim.fn.shellescape(opts.type)
  end
  if not opts.all then
    cmd = cmd .. ' --include-gitignored'
  end
  cmd = cmd .. ' 2>/dev/null'

  -- Execute command
  local output, err = execute_command(cmd)
  if not output or output == "" then
    if err then
      vim.notify("Error fetching cue artifacts: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("No cue artifacts found", vim.log.levels.INFO)
    end
    return nil
  end

  -- Parse JSON
  local artifacts, parse_err = parse_json(output)
  if not artifacts then
    vim.notify("Error parsing cue data: " .. (parse_err or "unknown"), vim.log.levels.ERROR)
    return nil
  end

  return artifacts
end

-- Open current context file
function M.open_context()
  local cmd = "cue context path 2>/dev/null"
  local output, err = execute_command(cmd)

  if not output or output == "" then
    -- Try to initialize context if not found
    vim.notify("Context not found, initializing...", vim.log.levels.INFO)
    local init_cmd = "cue context init 2>/dev/null"
    local init_output, init_err = execute_command(init_cmd)

    if not init_output then
      vim.notify("Error initializing context: " .. (init_err or "unknown"), vim.log.levels.ERROR)
      return
    end

    -- Try to get path again
    output, err = execute_command(cmd)
    if not output or output == "" then
      vim.notify("Error: " .. (err or "No current context found after init"), vim.log.levels.ERROR)
      return
    end
  end

  local path = vim.trim(output)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("Error: Context file does not exist: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(path)
end
--
-- Open current branch log
function M.open_log()
  local branch = get_current_branch()
  if not branch then
    vim.notify("Error: Could not determine current git branch", vim.log.levels.ERROR)
    return
  end

  local path = ".cue/" .. branch .. "/spec/log.md"
  if vim.fn.filereadable(path) == 0 then
    vim.notify("Error: Log file does not exist: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(path)
  vim.cmd("normal! G")
end

-- Open telescope picker for all context files
function M.pick_context()
  local cmd = "cue context path --all 2>/dev/null"
  local output, err = execute_command(cmd)

  if not output or output == "" then
    vim.notify("Error: " .. (err or "No context files found"), vim.log.levels.ERROR)
    return
  end

  local paths = {}
  for line in output:gmatch("[^\r\n]+") do
    local path = vim.trim(line)
    if path ~= "" then
      table.insert(paths, path)
    end
  end

  if #paths == 0 then
    vim.notify("No context files found", vim.log.levels.INFO)
    return
  end

  pickers.new({}, {
    prompt_title = "Cue Context Files",
    finder = finders.new_table({
      results = paths,
      entry_maker = make_entry.gen_from_file({}),
    }),
    previewer = conf.file_previewer({}),
    sorter = conf.file_sorter({}),
    attach_mappings = function(prompt_bufnr, _map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.cmd.edit(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

-- Show floating UI to select root status, then call callback(root)
local function select_root(callback)
  local items = {
    { label = "No",  root = false, desc = "Save as pinned artifact (timestamped, default)" },
    { label = "Yes", root = true,  desc = "Save in branch-specific directory" },
  }

  Snacks.picker.select(items, {
    prompt = "Save in branch root?",
    format_item = function(item)
      return string.format("%-3s  %s", item.label, item.desc)
    end,
  }, function(choice)
    if choice then
      callback(choice.root)
    end
  end)
end

-- Show floating UI to select artifact category, then call callback(category)
local function select_category(callback)
  local items = {
    { label = "todo",  desc = "TODO artifact" },
    { label = "spec",  desc = "Specification" },
    { label = "plan",  desc = "Plan artifact" },
    { label = "doc",   desc = "Documentation artifact" },
    { label = "trace", desc = "Trace / debug artifact" },
    { label = "bin",   desc = "Binary artifact" },
    { label = "tmp",   desc = "Temporary artifact" },
    { label = "ref",   desc = "Reference artifact" },
  }


  Snacks.picker.select(items, {
    prompt = "Select artifact type:",
    format_item = function(item)
      return string.format("%-8s  %s", item.label, item.desc)
    end,
  }, function(choice)
    if choice then
      callback(choice.label)
    end
  end)
end

-- Show floating input for filename, then call callback(filename)
local function prompt_filename(category, callback)
  Snacks.input({
    prompt = "Artifact filename (" .. category .. "):",
    completion = "file",
    win = { row = 0.3 },
  }, function(value)
    if not value or value == "" then
      value = "index.md"
    end
    callback(value)
  end)
end

-- Helper to prompt for root and then add
local function prompt_root_and_add(filename, opts)
  select_root(function(root)
    opts.root = root
    M.add(filename, opts)
  end)
end

-- Format category badge for display
local function format_category(category)
  return string.upper(category)
end

M.category_highlights = {
  spec = "CueCategorySpec",
  plan = "CueCategoryPlan",
  todo = "CueCategoryTodo",
  doc = "CueCategoryDoc",
  bin = "CueCategoryBin",
  trace = "CueCategoryTrace",
  tmp = "CueCategoryTmp",
  ref = "CueCategoryRef",
}

-- Default frontmatter for artifact types
M.TYPE_DEFAULTS = {
  todo = { status = "open", priority = "0" },
  plan = { status = "open", priority = "0" },
  doc = { status = "open" },
}

-- Get highlight group for category
local function get_category_highlight(category)
  return M.category_highlights[category] or "TelescopeResultsNormal"
end


-- Custom entry maker for mem artifacts
local function make_mem_entry_maker(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 5 },           -- category badge
      { width = 50 },          -- filename/title
      { width = 10 },          -- hash
      { remaining = true },    -- branch
    },
  }

  local make_display = function(entry)
    -- Handle vim.NIL from JSON null values
    local hash_display = "" ---@type string
    if entry.hash and entry.hash ~= vim.NIL then
      hash_display = entry.hash ---@type string
    end

    local display_name = utils.transform_path(opts, entry.name)
    local highlight = "TelescopeResultsNormal"

    -- Handle frontmatter
    if entry.frontmatter and entry.frontmatter ~= vim.NIL then
      local fm = entry.frontmatter
      if fm.title and fm.title ~= vim.NIL and fm.title ~= "" then
        display_name = fm.title .. " (" .. display_name .. ")"
      end
      if is_archived(entry) then
        highlight = "CueStatusArchived"
      elseif is_done(entry) then
        highlight = "CueStatusDone"
      end
    end

    return displayer {
      { format_category(entry.category), get_category_highlight(entry.category) },
      { display_name, highlight },
      { hash_display, "TelescopeResultsComment" },
      { entry.branch, "TelescopeResultsComment" },
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

    local fm_search = ""
    if entry.frontmatter and entry.frontmatter ~= vim.NIL then
      local fm = entry.frontmatter
      if fm.title and fm.title ~= vim.NIL then
        fm_search = fm_search .. " " .. fm.title
      end
      if fm.status and fm.status ~= vim.NIL then
        fm_search = fm_search .. " " .. fm.status
      end
    end

    local ordinal = string.format("%s %s %s %s%s",
      entry.name,
      hash_for_search,
      entry.branch,
      entry.category,
      fm_search
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
      frontmatter = entry.frontmatter, ---@type table?
    }, opts)
  end
end

-- Sort artifacts: current branch first, then by category, then by name
local function sort_artifacts(artifacts)
  local current_branch = get_current_branch()

  -- Category priority mapping
  local category_priority = {
    plan = 1,
    todo = 2,
    spec = 3,
    trace = 4,
    doc = 5,
    bin = 6,
    tmp = 7,
    ref = 8,
  }

  ---@param a table
  ---@param b table
  ---@return boolean
  table.sort(artifacts, function(a, b)
    -- First: done items at the bottom
    local a_finished = is_finished(a)
    local b_finished = is_finished(b)
    if a_finished ~= b_finished then
      return not a_finished
    end

    -- Second: current branch comes first
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

  local artifacts = get_cue_artifacts(opts)
  if not artifacts or #artifacts == 0 then
    return
  end

  -- Sort artifacts
  artifacts = sort_artifacts(artifacts) ---@type table

  -- Build prompt title
  local prompt_title = "Cue Artifacts"
  if opts.all then
    prompt_title = prompt_title .. " (All Branches)"
  else
    local branch = opts.branch or get_current_branch()
    if branch then
      prompt_title = prompt_title .. " (" .. branch .. ")"
    end
  end

  if opts.type then
    prompt_title = prompt_title .. " [" .. opts.type:upper() .. "]"
  end

  local picker_opts = {
    prompt_title = prompt_title, ---@type string
    finder = finders.new_table({
      results = artifacts, ---@type table
      entry_maker = make_mem_entry_maker(opts),
    }),
    sorter = conf.generic_sorter({}), ---@type table
    previewer = conf.file_previewer({}), ---@type table
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local entry = action_state.get_selected_entry() ---@type table
        if entry then
          vim.cmd.edit(entry.path)
        end
      end)

      -- Copy path to clipboard
      map({ 'i', 'n' }, '<C-y>', function()
        telescope_actions.copy_to_clipboard(prompt_bufnr, function(e)
          return vim.fn.fnamemodify(e.path, ":p")
        end, "path")
      end)

      -- Copy hash to clipboard
      map({ 'i', 'n' }, '<C-h>', function()
        telescope_actions.copy_to_clipboard(prompt_bufnr, function(e) return e.hash end, "hash")
      end)

      return true
    end,
  }

  pickers.new({}, picker_opts):find()
end

-- Add a new artifact file using cue add command and open it for editing
function M.add(filename, opts)
  opts = opts or {}

  -- Validate filename
  if not filename or filename == "" then
    vim.notify("Error: filename is required", vim.log.levels.ERROR)
    return nil
  end

  -- 1. Prepare the command and arguments
  local cmd = { 'cue', 'add', filename }

  -- Add type flag
  if opts.category then
    table.insert(cmd, '--type')
    table.insert(cmd, opts.category)
  end

  -- Add root flag
  if opts.root then
    table.insert(cmd, '--root')
  end

  -- Add branch flag
  if opts.branch then
    table.insert(cmd, '--branch')
    table.insert(cmd, opts.branch)
  end

  -- Add frontmatter flags
  if opts.frontmatter then
    for k, v in pairs(opts.frontmatter) do
      table.insert(cmd, '--frontmatter')
      table.insert(cmd, string.format("%s=%s", k, v))
    end
  end

  -- Add commit hash if provided and category allows it
  if opts.commit and (opts.category == "trace" or opts.category == "tmp") then
    table.insert(cmd, '--commit')
    table.insert(cmd, opts.commit)
  end

  -- Add force flag
  if opts.force then
    table.insert(cmd, '--force')
  end

  -- 2. Execute the command synchronously with :wait()
  -- text = true ensures the output is returned as a string, not a raw buffer
  local obj = vim.system(cmd, { text = true }):wait()

  -- 3. Check the exit code
  if obj.code ~= 0 then
    -- Prefer stderr for error messages, fallback to stdout if stderr is empty
    local error_msg = (obj.stderr and obj.stderr ~= "") and obj.stderr or obj.stdout

    -- Clean up whitespace (optional)
    error_msg = vim.trim(error_msg or "Unknown error")

    -- Notify the user of the error
    vim.notify("Cue Error: " .. error_msg, vim.log.levels.ERROR)

    return nil, error_msg
  end

  -- Parse output to get relative path
  local filepath = vim.trim(obj.stdout or "") ---@type string
  if filepath == "" then
    vim.notify("Error: failed to get file path from cue add output", vim.log.levels.ERROR)
    return nil
  end

  -- Notify success
  vim.notify("Successfully added: " .. filename, vim.log.levels.INFO)

  -- Open the file in a new buffer
  vim.cmd.edit(filepath)
  vim.cmd("normal! G")
  vim.cmd("startinsert!")

  return filepath
end

-- Helper to select a branch from predefined options or picker
local function select_branch_helper(callback)
  local items = {
    { label = "Current Branch", value = "current" },
    { label = "Master Branch",  value = vim.g.git_master or "master" },
    { label = "Base Branch",    value = vim.g.git_base or "master" },
    { label = "All Branches",   value = "all" },
    { label = "Select Branch...", value = "pick" },
  }

  Snacks.picker.select(items, {
    prompt = "Select Branch Scope:",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    if choice.value == "pick" then
      -- Call existing branch picker
      local cue_dir = ".cue"
      local branches = {}
      local p = io.popen('ls -d ' .. cue_dir .. '/*/ 2>/dev/null')
      if p then
        for line in p:lines() do
          local branch = line:match(".cue/(.+)/")
          if branch then table.insert(branches, branch) end
        end
        p:close()
      end
      if #branches == 0 then
        vim.notify("No branches with artifacts found", vim.log.levels.INFO)
        return
      end
      Snacks.picker.select(branches, {
        prompt = "Select Branch:",
      }, function(branch)
        if branch then callback(branch) end
      end)
    elseif choice.value == "current" then
      callback(nil) -- nil means current branch in pick_artifacts
    elseif choice.value == "all" then
      callback("all")
    else
      callback(choice.value)
    end
  end)
end

-- Guided UI for listing artifacts
function M.ui_pick()
  select_branch_helper(function(branch)
    select_category(function(category)
      local opts = {}
      if branch == "all" then
        opts.all = true
      else
        opts.branch = branch
      end
      opts.type = category
      M.pick_artifacts(opts)
    end)
  end)
end

-- Interactive artifact creation flows
function M.add_with_title(type, branch)
  Snacks.input({
    prompt = "Title (" .. type .. "):",
    win = { row = 0.3 },
  }, function(title)
    if not title or title == "" then return end

    local filename = slugify(title) .. ".md"
    local defaults = M.TYPE_DEFAULTS[type] or {}
    local frontmatter = vim.tbl_extend("force", { title = title }, defaults)

    local opts = {
      category = type,
      branch = branch,
      frontmatter = frontmatter
    }

    M.add(filename, opts)
  end)
end

function M.add_spec(branch)
  Snacks.input({
    prompt = "Spec path:",
    completion = "file",
    win = { row = 0.3 },
  }, function(path)
    if not path or path == "" then return end
    M.add(path, { category = "spec", branch = branch, root = true })
  end)
end

-- Picker for artifacts on a specific branch
function M.pick_branch_artifacts()
  local cue_dir = ".cue"
  if vim.fn.isdirectory(cue_dir) == 0 then
    vim.notify("Error: .cue directory not found", vim.log.levels.ERROR)
    return
  end

  local branches = {}
  local p = io.popen('ls -d ' .. cue_dir .. '/*/ 2>/dev/null')
  if p then
    for line in p:lines() do
      local branch = line:match(".cue/(.+)/")
      if branch then
        table.insert(branches, branch)
      end
    end
    p:close()
  end

  if #branches == 0 then
    vim.notify("No branches with artifacts found", vim.log.levels.INFO)
    return
  end

  Snacks.picker.select(branches, {
    prompt = "Select Branch:",
  }, function(branch)
    if branch then
      M.pick_artifacts({ branch = branch })
    end
  end)
end

-- ─── cue log ─────────────────────────────────────────────────────────────────

-- Parse the structured scratch buffer into a table suitable for cue log add
local function parse_log_buffer(lines)
  local entry = { title = nil, body = {}, found = {}, decided = {}, open = {} }
  local valid_sections = { title = true, body = true, found = true, decided = true, open = true }
  local section = "title"

  for _, line in ipairs(lines) do
    -- Section headers
    local header = line:match("^##%s+(%w+)")
    if header and valid_sections[header:lower()] then
      section = header:lower()
    else
      -- Content lines
      if section == "title" then
        if line ~= "" and not entry.title then
          entry.title = vim.trim(line)
        end
      elseif section == "body" then
        table.insert(entry.body, line)
      else
        -- List sections: found, decided, open
        local item = line:match("^%s*[%-%*]%s+(.+)") or (line ~= "" and vim.trim(line) or nil)
        if item and item ~= "" then
          table.insert(entry[section], item)
        end
      end
    end
  end

  -- Post-process body and title
  entry.body = #entry.body > 0 and vim.trim(table.concat(entry.body, "\n")) or nil
  if entry.body == "" then entry.body = nil end

  return entry
end

-- Build and run cue log add from a structured entry table
function M.log_add(entry)
  if not entry.title or entry.title == "" then
    vim.notify("Cue Log Error: Title is required", vim.log.levels.ERROR)
    return false
  end

  -- Write entry to a temp JSON file and use --file to avoid shell escaping
  local tmpfile = vim.fn.tempname() .. ".json"
  local data = {
    title = entry.title,
    body = entry.body or vim.NIL,
    found = #entry.found > 0 and entry.found or vim.NIL,
    decided = #entry.decided > 0 and entry.decided or vim.NIL,
    open = #entry.open > 0 and entry.open or vim.NIL,
  }

  local ok, err = pcall(function()
    local json = vim.fn.json_encode(data)
    local f = assert(io.open(tmpfile, "w"))
    f:write(json)
    f:close()
  end)

  if not ok then
    vim.notify("Cue Log Error: Failed to write temp file: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  local obj = vim.system({ "cue", "log", "add", "--file", tmpfile }, { text = true }):wait()
  vim.fn.delete(tmpfile)

  if obj.code ~= 0 then
    local msg = vim.trim((obj.stderr and obj.stderr ~= "") and obj.stderr or obj.stdout or "Unknown error")
    vim.notify("Cue Log Error: " .. msg, vim.log.levels.ERROR)
    return false
  end

  vim.notify("Cue Log: Entry added: " .. entry.title, vim.log.levels.INFO)
  return true
end

local LOG_TEMPLATE = {
  "## Title",
  "Write your title here",
  "",
  "## Body",
  "Optional multi-line body.",
  "",
  "## Found",
  "- ",
  "",
  "## Decided",
  "- ",
  "",
  "## Open",
  "- ",
}

-- Open the floating log form
function M.log_form()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, LOG_TEMPLATE)
  vim.bo[buf].modified = false

  local win = Snacks.win({
    buf = buf,
    width = 0.6,
    height = 0.7,
    border = "rounded",
    title = "  Cue Log Add  │  <C-s> Submit  │  q Cancel  ",
    title_pos = "center",
    wo = { wrap = true, linebreak = true, conceallevel = 2 },
  })

  -- Parse and submit
  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local entry = parse_log_buffer(lines)
    if M.log_add(entry) then
      win:close()
    end
  end

  -- Keymaps
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf, desc = "Submit cue log entry" })
  vim.keymap.set("n", "q", function() win:close() end, { buffer = buf, desc = "Cancel mem log entry" })

  -- Use BufWriteCmd to allow :w to submit
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = submit,
  })

  -- Initial cursor position (on the title line)
  vim.api.nvim_win_set_cursor(win.win, { 2, 0 })
  vim.cmd("startinsert!")
end

-- Setup user commands automatically when module loads
-- :CueLog [title] - Add cue log entry
vim.api.nvim_create_user_command('CueLog', function(args)
  local title = vim.trim(args.args)
  if title ~= "" then
    M.log_add({ title = title, found = {}, decided = {}, open = {} })
  else
    M.log_form()
  end
end, {
  nargs = "*",
  desc = "Add a cue log entry (no args = open form, with args = title-only fast path)"
})

-- :CueAdd - Add cue artifact (prompts for type then filename)
vim.api.nvim_create_user_command('CueAdd', function()
  select_category(function(category)
    prompt_filename(category, function(filename)
      prompt_root_and_add(filename, { category = category == "spec" and nil or category })
    end)
  end)
end, {
  nargs = 0,
  desc = 'Add a new cue artifact (prompts for type, filename, then root status)'
})
--
-- :CueAddBin <filename> - Add trace artifact
vim.api.nvim_create_user_command('CueAddBin', function(args)
  local filename = args.args
  if not filename or filename == "" then
    vim.notify("Usage: :CueAddBin <filename>", vim.log.levels.ERROR)
    return
  end
  prompt_root_and_add(filename, { category = 'bin' })
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Add a new cue trace artifact and open it for editing'
})

-- :CueAddTrace <filename> - Add trace artifact
vim.api.nvim_create_user_command('CueAddTrace', function(args)
  local filename = args.args
  if not filename or filename == "" then
    vim.notify("Usage: :CueAddTrace <filename>", vim.log.levels.ERROR)
    return
  end
  prompt_root_and_add(filename, { category = 'trace' })
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Add a new cue trace artifact and open it for editing'
})

-- :CueAddTmp <filename> - Add tmp artifact
vim.api.nvim_create_user_command('CueAddTmp', function(args)
  local filename = args.args
  if not filename or filename == "" then
    vim.notify("Usage: :CueAddTmp <filename>", vim.log.levels.ERROR)
    return
  end
  prompt_root_and_add(filename, { category = 'tmp' })
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Add a new cue tmp artifact and open it for editing'
})

-- :CueAddRef <filename> - Add ref artifact
vim.api.nvim_create_user_command('CueAddRef', function(args)
  local filename = args.args
  if not filename or filename == "" then
    vim.notify("Usage: :CueAddRef <filename>", vim.log.levels.ERROR)
    return
  end
  prompt_root_and_add(filename, { category = 'ref' })
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Add a new cue ref artifact and open it for editing'
})

-- :CueAddDoc <filename> - Add doc artifact
vim.api.nvim_create_user_command('CueAddDoc', function(args)
  local filename = args.args
  if not filename or filename == "" then
    vim.notify("Usage: :CueAddDoc <filename>", vim.log.levels.ERROR)
    return
  end
  prompt_root_and_add(filename, { category = 'doc' })
end, {
  nargs = 1,
  complete = 'file',
  desc = 'Add a new cue doc artifact and open it for editing'
})

return M
