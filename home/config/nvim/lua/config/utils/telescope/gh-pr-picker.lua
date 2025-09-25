local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local M = {}

-- Check if we're in a git repository
local function is_git_repo()
  local result = vim.fn.system('git rev-parse --git-dir 2>/dev/null')
  return vim.v.shell_error == 0
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

-- Get PR list from GitHub CLI
local function get_pr_list()
  if not is_git_repo() then
    vim.notify("Error: Not in a git repository", vim.log.levels.ERROR)
    return nil
  end

  local cmd = 'gh pr list --json number,title,author,headRefName,baseRefName,labels,url 2>/dev/null'
  local output, err = execute_command(cmd)

  if not output or output == "" then
    if err then
      vim.notify("Error fetching PRs: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("No open PRs found", vim.log.levels.INFO)
    end
    return nil
  end

  local prs, parse_err = parse_json(output)
  if not prs then
    vim.notify("Error parsing PR data: " .. (parse_err or "unknown"), vim.log.levels.ERROR)
    return nil
  end

  return prs
end

-- Format PR for display in telescope
local function format_pr_display(pr)
  local labels_str = ""
  if pr.labels and #pr.labels > 0 then
    local label_names = {}
    for _, label in ipairs(pr.labels) do
      table.insert(label_names, label.name)
    end
    labels_str = " [" .. table.concat(label_names, ", ") .. "]"
  end

  return string.format("#%d: %s%s (%s → %s)",
    pr.number,
    pr.title,
    labels_str,
    pr.headRefName,
    pr.baseRefName
  )
end

-- Checkout PR
local function checkout_pr(pr_number)
  local cmd = string.format('gh pr checkout %d 2>&1', pr_number)
  local output, err = execute_command(cmd)

  if err or vim.v.shell_error ~= 0 then
    vim.notify(string.format("Failed to checkout PR #%d: %s", pr_number, output or err), vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format("Successfully checked out PR #%d", pr_number), vim.log.levels.INFO)
  return true
end

-- Create PR preview
local function create_pr_previewer()
  return previewers.new_buffer_previewer({
    title = "PR Details",
    define_preview = function(self, entry, status)
      local pr = entry.value
      local cmd = string.format('gh pr view %d 2>/dev/null', pr.number)

      vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data and #data > 0 then
            -- Remove empty strings from data
            local filtered_data = {}
            for _, line in ipairs(data) do
              if line ~= "" then
                table.insert(filtered_data, line)
              end
            end

            if #filtered_data > 0 then
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, filtered_data)
              vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
            end
          end
        end,
        on_stderr = function(_, data)
          if data and #data > 0 then
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "Error loading PR details" })
          end
        end
      })
    end
  })
end

-- Main function to show PR picker
function M.pick_pr()
  local prs = get_pr_list()
  if not prs or #prs == 0 then
    return
  end

  pickers.new({}, {
    prompt_title = "GitHub Pull Requests",
    finder = finders.new_table({
      results = prs,
      entry_maker = function(pr)
        return {
          value = pr,
          display = format_pr_display(pr),
          ordinal = string.format("%d %s %s", pr.number, pr.title, pr.author.login),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = create_pr_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local entry = action_state.get_selected_entry()
        if entry then
          checkout_pr(entry.value.number)
        end
      end)

      -- Add custom mapping for opening PR in browser
      map('i', '<C-o>', function()
        local entry = action_state.get_selected_entry()
        if entry then
          local cmd = string.format('gh pr view %d --web', entry.value.number)
          vim.fn.jobstart(cmd, { detach = true })
        end
      end)

      map('n', '<C-o>', function()
        local entry = action_state.get_selected_entry()
        if entry then
          local cmd = string.format('gh pr view %d --web', entry.value.number)
          vim.fn.jobstart(cmd, { detach = true })
        end
      end)

      return true
    end,
  }):find()
end

-- Function to checkout PR by number (equivalent to your direct checkout)
function M.checkout_pr_by_number(pr_string)
  if not is_git_repo() then
    vim.notify("Error: Not in a git repository", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format('gh pr view "%s" --json number,baseRefName 2>/dev/null', pr_string)
  local output, err = execute_command(cmd)

  if not output or output == "" then
    vim.notify(string.format("Error: Could not find PR: %s", pr_string), vim.log.levels.ERROR)
    return
  end

  local pr_info, parse_err = parse_json(output)
  if not pr_info then
    vim.notify("Error parsing PR data: " .. (parse_err or "unknown"), vim.log.levels.ERROR)
    return
  end

  checkout_pr(pr_info.number)
end

-- Setup function for easy configuration
function M.setup(opts)
  opts = opts or {}

  -- Create user commands
  vim.api.nvim_create_user_command('GhPrPick', function()
    M.pick_pr()
  end, { desc = 'Pick and checkout a GitHub PR using Telescope' })

  vim.api.nvim_create_user_command('GhPrCheckout', function(args)
    if args.args == "" then
      vim.notify("Please provide a PR number or identifier", vim.log.levels.ERROR)
      return
    end
    M.checkout_pr_by_number(args.args)
  end, {
    nargs = 1,
    desc = 'Checkout a GitHub PR by number or identifier',
    complete = function()
      -- TODO: Could add completion for PR numbers
      return {}
    end
  })

  -- Optional keymaps
  if opts.mappings then
    for key, cmd in pairs(opts.mappings) do
      vim.keymap.set('n', key, cmd, { desc = 'GitHub PR action' })
    end
  end
end

return M
