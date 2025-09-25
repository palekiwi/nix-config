local M = {}

M.toggle_wrap = function()
  local wrap_status = vim.wo.wrap
  vim.wo.wrap = not wrap_status
end

M.toggle_relativenumber = function()
  local status = vim.wo.relativenumber
  vim.wo.relativenumber = not status
end

return M
