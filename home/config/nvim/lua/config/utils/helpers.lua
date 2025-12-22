M = {}

-- Tries to extract a filepath the system clipboard and open it in a buffer.
-- String can be either a GitHub file URL with possible line number,
-- or a string containing a file path relative to project root with line number.
M.open_on_line = function()
  local reg = vim.fn.getreg("+")
  assert(reg, "Clipboard is empty.")

  local str = reg:gsub("https://github.com/.+/blob/[^/]+/", "")

  --- TODO examine this regex
  local path = str:match("(%.?[%a%d%/%_%-]+%.[%a%._-]+)")

  local line_nr = str:match(":(%d+)") or str:match("#L(%d+)") or str:match("#(%d+)")

  local cmd = line_nr and string.format("e +%s %s", line_nr, path) or 'e ' .. path

  vim.cmd(cmd)
end

-- toggles quickfix window
M.toggle_quickfix = function()
  for _, win in pairs(vim.fn.getwininfo()) do
    if win["quickfix"] == 1 then
      vim.cmd "cclose"
    else
      vim.cmd "copen"
    end
  end
end

-- runs vert diffs between current versioned file and previous version
M.vert_diff_previous_version = function()
  local current_file = vim.fn.expand('%:t')
  local current_dir = vim.fn.expand('%:p:h')

  local base_name, version_str = current_file:match("(.*)_v(%d+)%.(.+)$")

  if not base_name or not version_str then
    vim.notify("File does not match versioned pattern (e.g., file_v07.sql)", vim.log.levels.ERROR)
    return
  end

  local current_version = tonumber(version_str)
  if current_version <= 1 then
    vim.notify("No previous version available (v01 is the first version)", vim.log.levels.WARN)
    return
  end

  local prev_version = current_version - 1
  local width = #version_str
  local prev_version_str = string.format("%0" .. width .. "d", prev_version)

  local extension = current_file:match("%.(.+)$")
  local prev_file = string.format("%s_v%s.%s", base_name, prev_version_str, extension)
  local prev_file_path = current_dir .. '/' .. prev_file

  if vim.fn.filereadable(prev_file_path) == 0 then
    vim.notify("Previous version file not found: " .. prev_file, vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("leftabove vert diffs %s", prev_file_path)
  vim.cmd(cmd)
end

return M
