local M = {}

M.DONE_STATUSES = {
  done = true,
  complete = true,
  closed = true,
}

M.TYPE_DEFAULTS = {
  todo = { status = "open", priority = "0" },
  plan = { status = "open", priority = "0" },
  doc  = { status = "open" },
}

M.category_highlights = {
  spec  = "CueCategorySpec",
  plan  = "CueCategoryPlan",
  todo  = "CueCategoryTodo",
  doc   = "CueCategoryDoc",
  bin   = "CueCategoryBin",
  trace = "CueCategoryTrace",
  tmp   = "CueCategoryTmp",
  ref   = "CueCategoryRef",
}

-- Resolved config (populated by apply())
M.values = {}

local defaults = {}

--- Merge user opts over defaults and store in M.values
---@param opts table|nil
function M.apply(opts)
  M.values = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
