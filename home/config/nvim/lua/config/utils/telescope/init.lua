local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local make_entry = require "telescope.make_entry"
local builtin = require 'telescope.builtin'

local git_utils = require('config.utils.git')
local gh_utils = require('config.utils.gh')

local custom_entry_makers = require('config.utils.telescope.entry_makers')
local custom_helpers = require('config.utils.telescope.helpers')
local custom_previewers = require('config.utils.telescope.previewers')

M = {}

local search_tags_opts = {
  fname_width = 60,
  show_line = false,
  only_sort_tags = true
}

M.find_in_agents = function()
  local branch_name = custom_helpers.current_git_branch()

  builtin.find_files({ cwd = ".agents/" .. branch_name })
end

M.file_review = function()
  local branch_name = custom_helpers.current_git_branch()
  local file_name = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
  local subdir = file_name:gsub("/", "_")

  local review_dir = ".agents/" .. branch_name .. "/review/files/" .. subdir

  builtin.find_files({
    cwd = review_dir,
    search_file = "review.md",
    no_ignore = true,
    layout_config = {
      preview_height = 0.9,
    }
  })
end

M.search_cword = function()
  builtin.grep_string {
    default_text = vim.fn.expand("<cfile>"),
    word_match = "-w"
  }
end

M.search_tags = function()
  builtin.tags(search_tags_opts)
end

M.search_tags_cword = function()
  local opts = vim.tbl_extend('force',
    search_tags_opts,
    { default_text = vim.fn.expand("<cword>") }
  )
  builtin.tags(opts)
end

M.lsp_references = function()
  builtin.lsp_references({
    include_declaration = true,
    fname_width = 60,
    show_line = false,
    trim_text = false
  })
end

--- search in files that have changed since a particular commit (base branch)
---@param search_dir string?
M.changed_files = function(search_dir)
  local success, result = pcall(custom_helpers.last_commit_on_base)

  if not success then
    vim.api.nvim_echo({
      { "Changed files: " .. result, "ErrorMsg" },
    }, true, {})
    return
  end

  local title = "Changed files"

  local git_cmd = "git diff --name-only " .. result

  if search_dir then
    git_cmd = git_cmd .. " -- " .. search_dir
    title = title .. ": " .. search_dir
  end

  local files = vim.fn.systemlist(git_cmd)

  local opts = {
    attach_mappings = function(_prompt_bufnr, map)
      map('i', '<C-l>', actions.smart_send_to_loclist + actions.open_loclist)

      return true
    end
  }

  pickers.new(opts, {
    prompt_title = title,
    finder = finders.new_table {
      results = files,
      entry_maker = make_entry.gen_from_file(opts)
    },
    previewer = custom_previewers.file_diff_previewer,
    sorter = conf.generic_sorter(opts),
  }):find()
end

-- live grep in change files
---@param search_dir string?
M.grep_changed_files = function(search_dir)
  local success, result = pcall(custom_helpers.last_commit_on_base)

  if not success then
    vim.api.nvim_echo({
      { "Changed files: " .. result, "ErrorMsg" },
    }, true, {})
    return
  end

  local title = "Changed files"

  local git_cmd = "git diff --name-only " .. result

  if search_dir then
    git_cmd = git_cmd .. " -- " .. search_dir
    title = title .. ": " .. search_dir
  end

  local files = vim.fn.systemlist(git_cmd)

  builtin.live_grep {
    prompt_title = "Grep in Changed Files",
    search_dirs = files
  }
end

M.changed_files_since = function(opts)
  local success, result = pcall(custom_helpers.last_commit_on_base)

  if not success then
    return vim.api.nvim_echo({
      { "Changed files: " .. result, "ErrorMsg" },
    }, true, {})
  end

  local base = vim.g.git_base or vim.g.git_master or "master"
  local commits = vim.fn.systemlist("git rev-list --ancestry-path " .. base .. "..HEAD --no-merges")

  local files = {};

  for _, commit in ipairs(commits) do
    local changed_in_commit = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. commit)
    files = vim.fn.extend(files, changed_in_commit)
  end

  opts = opts or {}

  pickers.new(opts, {
    prompt_title = "changed files",
    finder = finders.new_table {
      results = files,
      entry_maker = make_entry.gen_from_file(opts)
    },
    previewer = custom_previewers.file_diff_previewer,
    sorter = conf.generic_sorter(opts),
  }):find()
end

M.diffview_since = function()
  local success, result = pcall(custom_helpers.last_commit_on_base)

  if not success then
    return vim.api.nvim_echo({
      { "Changed files: " .. result, "ErrorMsg" },
    }, true, {})
  end

  local base = vim.g.git_base or vim.g.git_master or "master"
  local commits = vim.fn.systemlist("git rev-list --ancestry-path " .. base .. "..HEAD --no-merges")

  local files = {};

  for _, commit in ipairs(commits) do
    local changed_in_commit = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. commit)
    files = vim.fn.extend(files, changed_in_commit)
  end

  local cmd = "DiffviewOpen " .. base .. " -- " .. vim.fn.join(files, " ")
  vim.cmd(cmd)
end

M.git_commits = function(opts)
  local command = "git log -n 1000 --pretty=format:'%h %ai %<(20)%an %s'"

  local handle = assert(io.popen(command))
  local result = handle:read("*a")
  handle:close()

  local files = {}
  for token in string.gmatch(result, "[^\n]+") do
    table.insert(files, token)
  end

  opts = {
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selection = picker:get_multi_selection() ---@type table?

        if selection == nil or vim.tbl_isempty(selection) then
          local hash = action_state.get_selected_entry().value ---@type string

          actions.close(prompt_bufnr)

          vim.cmd(string.format("DiffviewOpen %s^!", hash))
          return
        end

        local size = #selection
        local first ---@type string
        local last ---@type string

        if size == 1 then
          first = selection[1].value ---@type string
          last = "HEAD"
        else
          first = selection[1].value ---@type string
          last = selection[size].value ---@type string
        end

        actions.close(prompt_bufnr)
        vim.cmd(string.format("DiffviewOpen %s...%s", first, last))
      end)

      map('i', '<C-h>', function()
        local hash = action_state.get_selected_entry().value ---@type string
        vim.fn.setreg('+', hash)

        actions.close(prompt_bufnr)
      end)

      map('i', '<C-y>', function()
        local hash = action_state.get_selected_entry().value ---@type string
        gh_utils.copy_commit_url(hash)

        actions.close(prompt_bufnr)
      end)

      map('i', '<C-b>', function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local git_base = selection.value ---@type string

        git_utils.set_base_branch(git_base)
      end)

      return true
    end
  }

  pickers.new(opts, {
    prompt_title = "PR Commits",
    layout_config = {
      preview_height = 0.5,
    },

    finder = finders.new_table {
      results = files,
      entry_maker = custom_entry_makers.gen_from_git_commits(opts)
    },
    previewer = {
      custom_previewers.diff_previewer,
      custom_previewers.changed_files_tree_previewer,
    },
    sorter = conf.generic_sorter(opts),
  }):find()
end

-- list "PR commits", i.e. commits that are present on current branch
-- but absent on the base branch
M.git_pr_commits = function(opts)
  local base_branch = vim.g.git_base
  local command = "git log --pretty=format:'%h %ai %<(20)%an %s' " .. "HEAD ^" .. base_branch

  local handle = assert(io.popen(command))
  local result = handle:read("*a")
  handle:close()

  local files = {}
  for token in string.gmatch(result, "[^\n]+") do
    table.insert(files, token)
  end

  opts = {
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selection = picker:get_multi_selection() ---@type table?

        if selection == nil or vim.tbl_isempty(selection) then
          local hash = action_state.get_selected_entry().value ---@type string

          actions.close(prompt_bufnr)

          vim.cmd(string.format("DiffviewOpen %s^!", hash))
          return
        end

        local size = #selection
        local first ---@type string
        local last ---@type string

        if size == 1 then
          first = selection[1].value ---@type string
          last = "HEAD"
        else
          first = selection[1].value ---@type string
          last = selection[size].value ---@type string
        end

        actions.close(prompt_bufnr)
        vim.cmd(string.format("DiffviewOpen %s...%s", first, last))
      end)

      map('i', '<C-h>', function()
        local hash = action_state.get_selected_entry().value ---@type string
        vim.fn.setreg('+', hash)

        actions.close(prompt_bufnr)
      end)

      map('i', '<C-y>', function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local selection = picker:get_multi_selection() ---@type table?

        if selection == nil or vim.tbl_isempty(selection) then
          -- Single selection - do what we already do
          local hash = action_state.get_selected_entry().value ---@type string
          gh_utils.copy_commit_url(hash)
        else
          local size = #selection
          if size == 2 then
            -- Two entries selected - save commit compare URL to registry
            local first_hash = selection[1].value ---@type string
            local second_hash = selection[2].value ---@type string
            gh_utils.copy_commit_compare_url(first_hash, second_hash)
          elseif size == 1 then
            -- One entry selected via multiselect
            local hash = selection[1].value ---@type string
            gh_utils.copy_commit_url(hash)
          else
            vim.notify("Select exactly 1 or 2 commits for URL generation")
            return
          end
        end

        actions.close(prompt_bufnr)
      end)

      map('i', '<C-b>', function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local git_base = selection.value ---@type string

        git_utils.set_base_branch(git_base)
      end)

      map('i', '<C-q>', function()
        local hash = action_state.get_selected_entry().value ---@type string

        actions.close(prompt_bufnr)

        local files = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. hash)

        if vim.v.shell_error ~= 0 or #files == 0 then
          vim.notify("No files found for commit " .. hash, vim.log.levels.WARN)
          return
        end

        local qf_list = {}
        for _, file in ipairs(files) do
          table.insert(qf_list, {
            filename = file,
            text = "Modified in commit " .. hash
          })
        end

        vim.fn.setqflist({}, 'r', { title = 'Files modified in commit ' .. hash, items = qf_list })
        vim.cmd('copen')
      end)

      return true
    end
  }

  pickers.new(opts, {
    prompt_title = "PR Commits",
    layout_config = {
      preview_height = 0.5,
    },

    finder = finders.new_table {
      results = files,
      entry_maker = custom_entry_makers.gen_from_git_commits(opts)
    },
    previewer = {
      custom_previewers.diff_previewer,
      custom_previewers.changed_files_tree_previewer,
    },
    sorter = conf.generic_sorter(opts),
  }):find()
end

M.git_pr_merge_commits = function(opts)
  local command = "git log --pretty=format:'%h %ai %<(20)%an %s %b' --merges --grep='Merge pull request' -n 1000"

  local handle = assert(io.popen(command))
  local result = handle:read("*a")
  handle:close()

  local commits = {}
  for token in string.gmatch(result, "[^\n]+") do
    -- local line = token:gsub("Merge pull request ", ""):gsub(" from [^%s]*", "")
    table.insert(commits, token)
  end

  opts = {
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local hash = action_state.get_selected_entry().value ---@type string
        actions.close(prompt_bufnr)
        vim.cmd(string.format("DiffviewOpen %s^!", hash))
      end)

      map('i', '<C-y>', function()
        local number_str = action_state.get_selected_entry().number ---@type string
        gh_utils.copy_pr_url_from_string(number_str)

        actions.close(prompt_bufnr)
      end)

      map('i', '<C-h>', function()
        local hash = action_state.get_selected_entry().value ---@type string
        vim.fn.setreg('+', hash)

        actions.close(prompt_bufnr)
      end)

      return true
    end
  }

  pickers.new(opts, {
    prompt_title = "PR Merge Commits",
    layout_config = {
      preview_height = 0.5,
    },
    finder = finders.new_table {
      results = commits,
      entry_maker = custom_entry_makers.gen_from_pr_commits(opts)
    },
    previewer = {
      custom_previewers.changed_files_previewer
    },
    sorter = conf.generic_sorter(opts),
  }):find()
end

return M
