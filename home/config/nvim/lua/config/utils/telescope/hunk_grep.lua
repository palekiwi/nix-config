local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local function parse_git_diff()
  -- Get git diff output against master
  local base = vim.g.git_base or vim.g.git_master or "master"
  local diff_cmd = "git diff " .. base .. " --no-prefix --unified=3"
  local diff_output = vim.fn.system(diff_cmd)

  if vim.v.shell_error ~= 0 then
    print("Error getting git diff against master")
    return {}
  end

  local hunks = {}
  local lines = vim.split(diff_output, '\n')
  local i = 1

  while i <= #lines do
    local line = lines[i]

    -- Look for file header (--- a/file or +++ b/file)
    if line:match("^%+%+%+ (.+)$") then
      local filename = line:match("^%+%+%+ (.+)$")
      i = i + 1

      -- Look for hunk headers
      while i <= #lines and lines[i]:match("^@@") do
        local hunk_header = lines[i]
        -- Parse @@ -old_start,old_count +new_start,new_count @@ context
        local new_start = hunk_header:match("@@.-(%+(%d+))")
        local start_line = new_start and tonumber(new_start:match("(%d+)")) or 1

        i = i + 1
        local hunk_content = {}
        local display_content = {}

        -- Collect hunk lines until next hunk or file
        while i <= #lines do
          local hunk_line = lines[i]
          if hunk_line:match("^@@") or hunk_line:match("^%+%+%+") or hunk_line:match("^%-%-%-") then
            break
          end
          -- Only include actual changes (+ and -), not context lines
          if hunk_line:match("^[%+%-]") then
            table.insert(hunk_content, hunk_line)
            -- For display, strip the +/- for cleaner searching but keep some indicator
            local clean_line = hunk_line:sub(2) -- remove +/- marker
            if hunk_line:match("^%+") then
              table.insert(display_content, "+ " .. clean_line)
            elseif hunk_line:match("^%-") then
              table.insert(display_content, "- " .. clean_line)
            end
          end
          i = i + 1
        end

        if #hunk_content > 0 then
          -- Create a summary line for display
          local added_lines = {}
          local removed_lines = {}
          for _, content_line in ipairs(hunk_content) do
            if content_line:match("^%+") then
              table.insert(added_lines, content_line:sub(2))
            elseif content_line:match("^%-") then
              table.insert(removed_lines, content_line:sub(2))
            end
          end

          -- Create a compact display
          local summary = ""
          if #removed_lines > 0 then
            summary = summary .. "-" .. table.concat(removed_lines, " "):sub(1, 40)
          end
          if #added_lines > 0 then
            if summary ~= "" then summary = summary .. " " end
            summary = summary .. "+" .. table.concat(added_lines, " "):sub(1, 40)
          end

          table.insert(hunks, {
            filename = filename,
            start_line = start_line,
            hunk_content = hunk_content,
            display_content = display_content,
            summary = summary,
            searchable_text = table.concat(display_content, " ")
          })
        end
      end
    else
      i = i + 1
    end
  end

  return hunks
end

local function git_diff_hunk_picker()
  local hunks = parse_git_diff()

  if #hunks == 0 then
    print("No changes found in git diff")
    return
  end

  pickers.new({}, {
    prompt_title = 'Git Diff Hunks',
    finder = finders.new_table {
      results = hunks,
      entry_maker = function(hunk)
        return {
          value = hunk,
          display = string.format("%s:%d", hunk.filename, hunk.start_line),
          ordinal = hunk.searchable_text, -- Only search hunk content, not filename
          filename = hunk.filename,
          lnum = hunk.start_line,
        }
      end
    },
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Diff Hunk",
      define_preview = function(self, entry, status)
        local hunk = entry.value

        -- Create preview content with file header and hunk
        local preview_lines = {
          "File: " .. hunk.filename,
          "Line: " .. hunk.start_line,
          "",
        }

        -- Add the actual hunk content with proper diff formatting
        for _, line in ipairs(hunk.hunk_content) do
          table.insert(preview_lines, line)
        end

        -- Set the preview content
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)

        -- Set diff filetype for syntax highlighting
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'diff')

        -- Highlight search matches only in the hunk content (not filename)
        local prompt = vim.api.nvim_buf_get_lines(status.prompt_bufnr, 0, 1, false)[1] or ""
        if prompt ~= "" then
          -- Search for the prompt only in hunk content lines (starting from line 4, after header)
          for i, line in ipairs(hunk.hunk_content) do
            local line_num = i + 3                -- account for header lines
            -- Remove the +/- prefix for matching, but highlight in the original line
            local content_to_search = line:sub(2) -- remove +/- marker
            local start_pos = 1
            while true do
              local match_start, match_end = string.find(content_to_search:lower(), prompt:lower(), start_pos, true)
              if not match_start then break end

              -- Adjust highlight position to account for the +/- prefix
              vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, 'TelescopeMatching',
                line_num - 1, match_start, match_end + 1) -- +1 to account for removed prefix
              start_pos = match_end + 1
            end
          end
        end
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()

        -- Open the file and go to the hunk start
        vim.cmd('edit ' .. selection.filename)
        vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })

        -- Center the line on screen
        vim.cmd('normal! zz')

        -- Optional: briefly highlight the hunk area
        local hunk_size = #selection.value.hunk_content
        for i = 0, hunk_size - 1 do
          if selection.lnum + i <= vim.api.nvim_buf_line_count(0) then
            vim.api.nvim_buf_add_highlight(0, -1, 'Search', selection.lnum + i - 1, 0, -1)
          end
        end

        -- Clear highlights after 2 seconds
        vim.defer_fn(function()
          vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)
        end, 2000)
      end)

      return true
    end,
  }):find()
end

return git_diff_hunk_picker
