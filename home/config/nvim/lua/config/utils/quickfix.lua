local M = {}

function M.add_cursor_to_qf(text)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.fn.setqflist({ {
    filename = vim.fn.expand('%'),
    lnum = cursor[1],
    col = cursor[2] + 1,
    text = text or "Cursor position"
  } }, 'a')
end

return M

