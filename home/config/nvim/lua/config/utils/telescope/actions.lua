local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"

local M = {}

--- Copy selected entries to clipboard
---@param prompt_bufnr number
---@param get_value function
---@param label string
M.copy_to_clipboard = function(prompt_bufnr, get_value, label)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local selection = picker:get_multi_selection()
  local results = {}

  if selection == nil or vim.tbl_isempty(selection) then
    local entry = action_state.get_selected_entry()
    if entry then
      local val = get_value(entry)
      if val and val ~= vim.NIL and val ~= "" then
        table.insert(results, val)
      end
    end
  else
    for _, entry in ipairs(selection) do
      local val = get_value(entry)
      if val and val ~= vim.NIL and val ~= "" then
        table.insert(results, val)
      end
    end
  end

  if #results > 0 then
    local final_val = table.concat(results, "\n")
    vim.fn.setreg('+', final_val)
    local msg = "Copied " .. label .. ": " .. (#results > 1 and (#results .. " items") or final_val)
    vim.notify(msg, vim.log.levels.INFO)
    actions.close(prompt_bufnr)
  else
    vim.notify("No " .. label .. " available to copy", vim.log.levels.WARN)
  end
end

return M
