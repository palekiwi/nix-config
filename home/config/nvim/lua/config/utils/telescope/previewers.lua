local previewers = require "telescope.previewers"
local utils = require('telescope.previewers.utils')

local ns_id = vim.api.nvim_create_namespace("custom_telescope_previewers")

M = {}

M.changed_files_tree_previewer = previewers.new_buffer_previewer({
  title = "Changed Files",
  define_preview = function(self, entry, _status)
    local commit_hash = entry.value:match("^(%w+)") ---@type string

    -- Get file names with status
    local changed_files = vim.fn.system(string.format(
      "git show --name-status --format='' %s",
      commit_hash
    ))

    -- Define custom highlight group for renames
    vim.api.nvim_set_hl(0, 'GitFileRenamed', { fg = '#de935f', bold = true }) -- Orange/bold

    local function get_status_highlight(status)
      local highlights = {
        A = "GitSignsAdd",         -- Added (green)
        M = "GitSignsChange",      -- Modified (blue/yellow)
        D = "GitSignsDelete",      -- Deleted (red)
        ["R+"] = "GitFileRenamed", -- Renamed to (orange)
        ["R-"] = "GitFileRenamed", -- Renamed from (orange)
        T = "GitSignsChange",      -- Type changed (blue/yellow)
        U = "ErrorMsg",            -- Unmerged (red/error)
      }

      -- Handle rename statuses like "R063"
      if status:match("^R") then
        return "GitFileRenamed"
      end

      return highlights[status] or "Normal"
    end

    local function create_tree_structure(file_data)
      local tree = {}

      for _, data in ipairs(file_data) do
        if data.status:match("^R") and data.old_path and data.new_path then
          -- Handle renamed files - show both old and new paths
          local old_parts = vim.split(data.old_path, '/')
          local new_parts = vim.split(data.new_path, '/')

          -- Add old path (marked as deleted)
          local current = tree
          for i, part in ipairs(old_parts) do
            if i == #old_parts then
              current[part .. " [R-]"] = { status = "R-" }
            else
              if not current[part] then
                current[part] = {}
              end
              current = current[part]
            end
          end

          -- Add new path (marked as added)
          current = tree
          for i, part in ipairs(new_parts) do
            if i == #new_parts then
              current[part .. " [R+]"] = { status = "R+" }
            else
              if not current[part] then
                current[part] = {}
              end
              current = current[part]
            end
          end
        else
          -- Handle normal files
          local parts = vim.split(data.path, '/')
          local current = tree

          for i, part in ipairs(parts) do
            if i == #parts then
              -- Last part (filename) - store with status
              current[part .. " [" .. data.status .. "]"] = { status = data.status }
            else
              -- Directory part
              if not current[part] then
                current[part] = {}
              end
              current = current[part]
            end
          end
        end
      end

      return tree
    end

    local function format_tree(tree, prefix, _is_last, lines, highlights)
      lines = lines or {}
      highlights = highlights or {}
      local keys = vim.tbl_keys(tree)
      table.sort(keys)

      for i, key in ipairs(keys) do
        local is_last_item = (i == #keys)
        local connector = is_last_item and "└── " or "├── "
        local line_content = prefix .. connector .. key
        local line_number = #lines + 1

        table.insert(lines, line_content)

        -- Check if this is a file with status (has status field)
        if tree[key].status then
          local status = tree[key].status
          local highlight_group = get_status_highlight(status)

          -- Find the status bracket position
          local bracket_start = line_content:find("%[")
          if bracket_start then
            -- Highlight the entire line with the status color
            table.insert(highlights, {
              line = line_number,
              col_start = 0,
              col_end = #line_content,
              hl_group = highlight_group
            })

            -- Add extra highlighting for the status bracket
            table.insert(highlights, {
              line = line_number,
              col_start = bracket_start - 1,
              col_end = #line_content,
              hl_group = highlight_group
            })
          end
        else
          -- Directory - highlight with Directory color
          local dir_start = #(prefix .. connector)
          table.insert(highlights, {
            line = line_number,
            col_start = dir_start,
            col_end = #line_content,
            hl_group = "Directory"
          })
        end

        if next(tree[key]) and not tree[key].status then
          local new_prefix = prefix .. (is_last_item and "    " or "│   ")
          format_tree(tree[key], new_prefix, is_last_item, lines, highlights)
        end
      end

      return lines, highlights
    end

    -- Parse the git output to extract status and file paths
    local file_data = {}
    for line in changed_files:gmatch("[^\n]+") do
      if line ~= "" then
        local status = line:match("^(%w+)")
        if status:match("^R") then
          -- Handle renamed files: "R100    old/path.txt    new/path.txt"
          local old_path, new_path = line:match("^R%d*%s+(.-)%s+(.+)$")
          if old_path and new_path then
            table.insert(file_data, {
              status = status,
              old_path = old_path,
              new_path = new_path
            })
          end
        else
          -- Handle normal files: "M    path/to/file.txt"
          local filepath = line:match("^%w+%s+(.+)$")
          if filepath then
            table.insert(file_data, { status = status, path = filepath })
          end
        end
      end
    end

    local tree = create_tree_structure(file_data)
    local formatted_lines, highlights = format_tree(tree, "")

    -- Set the content
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, formatted_lines)

    -- Apply syntax highlighting
    vim.api.nvim_set_option_value('filetype', 'git', { buf = self.state.bufnr })

    -- Apply custom highlights
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(
        self.state.bufnr,
        ns_id,          -- namespace
        hl.line - 1, -- 0-indexed
        hl.col_start,
        {
          end_col = hl.col_end,
          hl_group = hl.hl_group
        }
      )
    end
  end
})

M.changed_files_previewer = previewers.new_buffer_previewer({
  title = "Changed Files",
  define_preview = function(self, entry, _status)
    local commit_hash = entry.value:match("^(%w+)") ---@type string

    -- Get just the file names
    local changed_files = vim.fn.system(string.format(
      "git diff --name-status %s^1..%s",
      commit_hash,
      commit_hash
    ))

    local lines = {}
    for filename in changed_files:gmatch("[^\n]+") do
      if filename ~= "" then
        table.insert(lines, filename)
      end
    end

    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

    -- Add syntax highlighting for git status
    vim.api.nvim_buf_call(self.state.bufnr, function()
      vim.cmd("syntax clear")
      vim.cmd("syntax match GitAdded /^A\\s.*$/")
      vim.cmd("syntax match GitDeleted /^D\\s.*$/")
      vim.cmd("syntax match GitRenamed /^R[0-9]*\\s.*$/")
      vim.cmd("syntax match GitCopied /^C[0-9]*\\s.*$/")

      vim.cmd("highlight GitAdded ctermfg=Green guifg=#6e9440")
      vim.cmd("highlight GitDeleted ctermfg=Red guifg=#cc6666")
      vim.cmd("highlight GitRenamed ctermfg=Blue guifg=#85678f")
      vim.cmd("highlight GitCopied ctermfg=Cyan guifg=#de935f")
    end)
  end,
})


M.diff_previewer = previewers.new_buffer_previewer({
  title = "Git Diff",
  define_preview = function(self, entry, _status)
    local commit_hash = entry.value:match("^(%w+)") ---@type string

    local diff_output = vim.fn.system(string.format(
      "git --no-pager show --color=never --unified=0 --format= %s",
      commit_hash
    ))

    local lines = {}
    local current_file = nil
    local first_file = true

    for line in diff_output:gmatch("[^\n]+") do
      if line:match("^diff %-%-git ") then
        -- Add spacing before each file (except the first one)
        if not first_file then
          table.insert(lines, "")
        end
        first_file = false

        -- Extract filename from diff --git a/file b/file
        current_file = line:match(" b/(.+)$")
        table.insert(lines, current_file)

        -- Skip index, ---, +++ lines, keep everything else
      elseif not line:match("^index ") and not line:match("^%-%-%- ") and not line:match("^%+%+%+ ") then
        table.insert(lines, line)
      end
    end

    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    utils.highlighter(self.state.bufnr, "diff")
  end,
})


M.file_diff_previewer = previewers.new_buffer_previewer({
  title = "File Diff",
  define_preview = function(self, entry, _status)
    local base_branch = vim.g.git_base or vim.g.git_master or "master"

    local diff_output = vim.fn.system(
      "git --no-pager diff --color=never --unified=3 " .. base_branch .. '..HEAD ' .. entry.value
    )

    local lines = {}

    for line in diff_output:gmatch("[^\n]+") do
      if not line:match("^index ") and not line:match("^diff %-%-git ") and not line:match("^%-%-%- ") and not line:match("^%+%+%+ ") then
        table.insert(lines, line)
      end
    end

    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    utils.highlighter(self.state.bufnr, "diff")
  end,
})

return M
