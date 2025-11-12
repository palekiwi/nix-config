local M = {}

M.copy_file_path = function(include_cursor)
  local filepath = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
  local result = filepath

  if include_cursor then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local col = cursor[2] + 1
    result = string.format("%s L%d:C%d", filepath, line, col)
  end

  vim.fn.setreg('+', result)
  vim.notify(string.format("Copied: %s", result), vim.log.levels.INFO)
end

M.copy_diagnostic_on_line = function()
  local filepath = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1] - 1
  local col = cursor[2] + 1
  local diagnostics = vim.diagnostic.get(0, { lnum = cursor_line })

  if #diagnostics == 0 then
    vim.notify("No diagnostics on current line", vim.log.levels.WARN)
    return
  end

  local result = { string.format("%s L%d:C%d", filepath, cursor_line + 1, col) }
  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    table.insert(result, string.format("[%s] %s", severity, diag.message))
  end

  local output = table.concat(result, "\n")
  vim.fn.setreg('+', output)
  vim.notify(string.format("Copied %d diagnostic(s)", #diagnostics), vim.log.levels.INFO)
end

M.copy_diagnostics_for_file = function()
  local diagnostics = vim.diagnostic.get(0)

  if #diagnostics == 0 then
    vim.notify("No diagnostics in current file", vim.log.levels.WARN)
    return
  end

  local filepath = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
  local result = { string.format("Diagnostics for %s:\n", filepath) }

  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    local line = diag.lnum + 1
    local col = diag.col + 1
    table.insert(result, string.format("L%d:C%d [%s] %s", line, col, severity, diag.message))
  end

  local output = table.concat(result, "\n")
  vim.fn.setreg('+', output)
  vim.notify(string.format("Copied %d diagnostic(s)", #diagnostics), vim.log.levels.INFO)
end

M.copy_file_with_visual_range = function()
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')  ---@type integer

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local filepath = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
  local result ---@type string
  if start_line == end_line then
    result = string.format("%s L%d", filepath, start_line)
  else
    result = string.format("%s L%d-L%d", filepath, start_line, end_line)
  end

  vim.fn.setreg('+', result)
  vim.notify(string.format("Copied: %s", result), vim.log.levels.INFO)
end

return M
