local M = {}

function M.show(opts)
  opts = opts or {}
  local all_hunks = opts.all or false

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local utils = require('telescope.previewers.utils')

  local current_file = vim.fn.expand('%:p')

  -- Get git root
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')
  if vim.v.shell_error ~= 0 then
    print("Not in a git repository")
    return
  end
  git_root = git_root[1]

  -- Get relative path
  local relative_path = current_file:sub(#git_root + 2)

  -- Read JSON file
  local json_path = git_root .. '/.git/hunk-comments/HEAD.json'
  local file = io.open(json_path, 'r')
  if not file then
    print("No hunk comments file found")
    return
  end

  local json_content = file:read('*all')
  file:close()

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, json_content)
  if not ok then
    print("Failed to parse hunk comments JSON")
    return
  end

  -- Filter comments
  local filtered_hunks = {}
  if all_hunks then
    -- Show all hunks
    filtered_hunks = data.hunks or {}
  else
    -- Filter comments for current buffer
    for _, hunk in ipairs(data.hunks or {}) do
      if hunk.file == relative_path then
        table.insert(filtered_hunks, hunk)
      end
    end
  end

  if #filtered_hunks == 0 then
    if all_hunks then
      print("No hunk comments found")
    else
      print("No hunk comments for current buffer")
    end
    return
  end

  -- Create telescope picker
  pickers.new({}, {
    prompt_title = all_hunks and "All Hunk Comments" or "Hunk Comments",
    finder = finders.new_table({
      results = filtered_hunks,
      entry_maker = function(hunk)
        local display_comment = hunk.comment:sub(1, 60)
        if #hunk.comment > 60 then
          display_comment = display_comment .. "..."
        end

        return {
          value = hunk,
          display = string.format("Lines %d-%d [%s]: %s",
            hunk.line_start, hunk.line_end, hunk.change_type, display_comment),
          ordinal = hunk.comment .. " " .. hunk.change_type .. " " .. hunk.line_start .. " " .. hunk.line_end
        }
      end
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Jump to the hunk location
          vim.api.nvim_win_set_cursor(0, { selection.value.line_start, 0 })
        end
      end)
      return true
    end,
    previewer = require('telescope.previewers').new_buffer_previewer({
      define_preview = function(self, entry, status)
        local bufnr = self.state.bufnr
        local lines = {
          "File: " .. entry.value.file,
          "Lines: " .. entry.value.line_start .. "-" .. entry.value.line_end,
          "Type: " .. entry.value.change_type,
          "",
          "Comment:",
          entry.value.comment
        }

        if entry.value.diff then
          table.insert(lines, "")
          table.insert(lines, "Diff:")
          -- Split diff into lines and add them
          for diff_line in entry.value.diff:gmatch("[^\r\n]+") do
            table.insert(lines, diff_line)
          end
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        -- Apply diff syntax highlighting
        utils.highlighter(bufnr, "diff")
      end
    })
  }):find()
end



return M
