local M = {}

local ns = vim.api.nvim_create_namespace("cue_review")

local severity_map = {
  critical = vim.diagnostic.severity.ERROR,
  high     = vim.diagnostic.severity.ERROR,
  medium   = vim.diagnostic.severity.WARN,
  low      = vim.diagnostic.severity.INFO,
}

local qf_type_map = {
  critical = "E",
  high     = "E",
  medium   = "W",
  low      = "I",
}

-- Cached state for active review findings
local current_review = {
  metadata = nil,
  findings = {},
  source_path = nil,
  repo_root = nil,
  stats = {
    total = 0,
    actionable = 0,
    applied = 0,
    dismissed = 0,
  },
}

--- Return the cue_review diagnostic namespace
---@return integer
function M.get_namespace()
  return ns
end

--- Return current loaded review data
---@return table
function M.get_current_review()
  return current_review
end

--- Resolve repository root directory
---@param source_path string|nil
---@param metadata table|nil
---@return string
local function get_repo_root(source_path, metadata)
  if metadata and metadata.repo_root and vim.fn.isdirectory(metadata.repo_root) == 1 then
    return metadata.repo_root
  end

  if source_path then
    local root_from_cue = source_path:match("^(.-)/%.cue/")
    if root_from_cue and vim.fn.isdirectory(root_from_cue) == 1 then
      return root_from_cue
    end
  end

  local obj = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if obj.code == 0 and obj.stdout and vim.trim(obj.stdout) ~= "" then
    return vim.trim(obj.stdout)
  end
  return vim.fn.getcwd()
end

--- Check current git HEAD vs review metadata commit SHA (head_sha only)
---@param head_sha string|nil
---@param repo_root string
local function check_git_rev(head_sha, repo_root)
  if not head_sha or head_sha == "" or head_sha == vim.NIL then
    return
  end

  local obj = vim.system({ "git", "rev-parse", "HEAD" }, { text = true, cwd = repo_root }):wait()
  if obj.code == 0 then
    local current_sha = vim.trim(obj.stdout)
    if not vim.startswith(current_sha, head_sha) and not vim.startswith(head_sha, current_sha) then
      vim.notify(
        string.format(
          "[cue-review] Revision drift detected:\nFindings reviewed at commit %s\nCurrent HEAD is at %s\nLine numbers may have shifted.",
          string.sub(head_sha, 1, 7),
          string.sub(current_sha, 1, 7)
        ),
        vim.log.levels.WARN
      )
    end
  end
end

--- Format diagnostic message from a finding table
---@param finding table
---@return string
local function format_diagnostic_message(finding)
  local parts = {}

  local title = finding.title or "Review Finding"
  local category = finding.category or "General"
  local severity = string.upper(finding.severity or "INFO")
  local status = finding.status or "open"

  local status_tag = ""
  if status == "applied" then
    status_tag = " [APPLIED]"
  elseif status == "dismissed" then
    status_tag = " [DISMISSED]"
  end

  table.insert(parts, string.format("[%s] [%s]%s %s", category, severity, status_tag, title))

  if finding.message and finding.message ~= "" and finding.message ~= vim.NIL then
    table.insert(parts, "\n" .. finding.message)
  end

  if finding.verification and type(finding.verification) == "table" then
    local v = finding.verification
    local verdict = v.verdict or "verified"
    local verifier = v.verifier and (" by " .. v.verifier) or ""
    local reasoning = v.reasoning or ""
    table.insert(parts, string.format("\n--- Verification (%s%s) ---\n%s", string.upper(verdict), verifier, reasoning))
  end

  if finding.suggested_fix and finding.suggested_fix ~= "" and finding.suggested_fix ~= vim.NIL then
    table.insert(parts, string.format("\n--- Suggested Fix ---\n%s", finding.suggested_fix))
  end

  if finding.unverified and type(finding.unverified) == "table" and #finding.unverified > 0 then
    local unv_lines = {}
    for _, u in ipairs(finding.unverified) do
      table.insert(unv_lines, "- " .. u)
    end
    table.insert(parts, string.format("\n--- Unverified Claims ---\n%s", table.concat(unv_lines, "\n")))
  end

  return table.concat(parts, "\n")
end

--- Load parsed review data into vim.diagnostic
---@param data table
---@param source_label string
---@param source_path string|nil
---@param opts table|nil  supports: all (boolean, include applied/dismissed)
---@return boolean
function M.load_data(data, source_label, source_path, opts)
  opts = opts or {}
  local include_all = opts.all == true

  if not data or not data.findings or type(data.findings) ~= "table" then
    vim.notify("[cue-review] Invalid findings format: missing 'findings' array", vim.log.levels.ERROR)
    return false
  end

  local repo_root = get_repo_root(source_path, data.metadata)

  -- Only check revision drift if head_sha is explicitly provided (never compare merge_base to HEAD)
  if data.metadata and type(data.metadata) == "table" and data.metadata.head_sha then
    check_git_rev(data.metadata.head_sha, repo_root)
  end

  -- Clear previous review diagnostics
  vim.diagnostic.reset(ns)

  local by_file = {}
  local loaded_findings = {}

  local count_total = #data.findings
  local count_actionable = 0
  local count_applied = 0
  local count_dismissed = 0

  for _, finding in ipairs(data.findings) do
    local status = finding.status or "open"
    local is_refuted = finding.verification and finding.verification.verdict == "refuted"
    local is_dismissed = status == "dismissed" or is_refuted
    local is_applied = status == "applied"

    if is_applied then
      count_applied = count_applied + 1
    elseif is_dismissed then
      count_dismissed = count_dismissed + 1
    else
      count_actionable = count_actionable + 1
    end

    local should_include = include_all or (not is_dismissed and not is_applied)

    if should_include then
      local rel_file = finding.file
      if rel_file and rel_file ~= "" and rel_file ~= vim.NIL then
        local abs_path = vim.fs.joinpath(repo_root, rel_file)
        by_file[abs_path] = by_file[abs_path] or {}

        local line_start = math.max(0, (finding.line_start or 1) - 1)
        local line_end   = math.max(line_start, (finding.line_end or finding.line_start or 1) - 1)

        local models = finding.models or (finding.model and { finding.model }) or {}
        local models_str = #models > 0 and table.concat(models, ", ") or "cue-review"

        local diag_severity = severity_map[finding.severity] or vim.diagnostic.severity.WARN
        if is_applied or is_dismissed then
          diag_severity = vim.diagnostic.severity.HINT
        end

        local diag = {
          lnum = line_start,
          end_lnum = line_end,
          col = 0,
          severity = diag_severity,
          message = format_diagnostic_message(finding),
          source = string.format("cue-review (%s)", models_str),
          user_data = {
            finding = finding,
            category = finding.category,
            confidence = finding.confidence,
            suggested_fix = finding.suggested_fix,
            verification = finding.verification,
          },
        }

        table.insert(by_file[abs_path], diag)
        table.insert(loaded_findings, finding)
      end
    end
  end

  -- Register buffers and set diagnostics
  for abs_path, diags in pairs(by_file) do
    local bufnr = vim.fn.bufadd(abs_path)
    vim.diagnostic.set(ns, bufnr, diags, {})
  end

  current_review.metadata = data.metadata
  current_review.findings = loaded_findings
  current_review.source_path = source_path
  current_review.repo_root = repo_root
  current_review.stats = {
    total = count_total,
    actionable = count_actionable,
    applied = count_applied,
    dismissed = count_dismissed,
  }

  local run_info = ""
  if data.metadata and data.metadata.run_id then
    run_info = string.format(" (run %s)", data.metadata.run_id)
  end

  if count_actionable == 0 and not include_all and count_total > 0 then
    vim.notify(
      string.format(
        "[cue-review] All %d findings in %s are already resolved (%d applied, %d dismissed/refuted).\nUse :CueReviewLoad all or <A-a> in picker to view all.",
        count_total,
        source_label,
        count_applied,
        count_dismissed
      ),
      vim.log.levels.INFO
    )
  else
    local label = include_all and string.format("%d (all)", #loaded_findings) or tostring(#loaded_findings)
    vim.notify(
      string.format("[cue-review] Loaded %s findings into diagnostics from %s%s", label, source_label, run_info),
      vim.log.levels.INFO
    )
  end

  return true
end

--- Load findings from a file on disk
---@param path string
---@param opts table|nil
---@return boolean
function M.load_file(path, opts)
  local expanded = vim.fn.expand(path)
  local file = io.open(expanded, "r")
  if not file then
    vim.notify("[cue-review] Could not open file: " .. expanded, vim.log.levels.ERROR)
    return false
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data then
    vim.notify("[cue-review] Failed to parse JSON in: " .. expanded, vim.log.levels.ERROR)
    return false
  end

  local label = vim.fn.fnamemodify(expanded, ":t")
  return M.load_data(data, label, expanded, opts)
end

--- Load findings from the current active buffer
---@param opts table|nil
---@return boolean
function M.load_current_buffer(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data or not data.findings then
    vim.notify("[cue-review] Current buffer does not contain valid review findings JSON", vim.log.levels.ERROR)
    return false
  end

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local label = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":t") or "buffer"
  return M.load_data(data, label, buf_name ~= "" and buf_name or nil, opts)
end

--- Clear all review diagnostics
function M.clear()
  vim.diagnostic.reset(ns)
  current_review.metadata = nil
  current_review.findings = {}
  current_review.source_path = nil
  current_review.repo_root = nil
  current_review.stats = { total = 0, actionable = 0, applied = 0, dismissed = 0 }
  vim.notify("[cue-review] Cleared review diagnostics", vim.log.levels.INFO)
end

--- Export loaded review findings to Quickfix list
function M.to_quickfix()
  if not current_review.findings or #current_review.findings == 0 then
    vim.notify("[cue-review] No active review findings loaded to export to Quickfix", vim.log.levels.WARN)
    return
  end

  local repo_root = current_review.repo_root or get_repo_root(current_review.source_path, current_review.metadata)
  local qf_list = {}

  for _, finding in ipairs(current_review.findings) do
    local rel_file = finding.file
    local abs_path = rel_file and vim.fs.joinpath(repo_root, rel_file) or ""
    local title = finding.title or ""
    local category = finding.category or "General"
    local severity = finding.severity or "medium"
    local status = finding.status or "open"

    local tag = ""
    if status == "applied" then
      tag = " [APPLIED]"
    elseif status == "dismissed" then
      tag = " [DISMISSED]"
    end

    table.insert(qf_list, {
      filename = abs_path,
      lnum = finding.line_start or 1,
      end_lnum = finding.line_end or finding.line_start or 1,
      col = 1,
      text = string.format("[%s] [%s]%s %s", category, string.upper(severity), tag, title),
      type = qf_type_map[severity] or "I",
    })
  end

  local title = "Cue Review Findings"
  if current_review.metadata and current_review.metadata.run_id then
    title = string.format("Cue Review (%s)", current_review.metadata.run_id)
  end

  vim.fn.setqflist(qf_list, "r")
  vim.fn.setqflist({}, "a", { title = title })
  vim.cmd("copen")
end

--- Setup user commands
function M.setup()
  vim.api.nvim_create_user_command("CueReviewLoad", function(cmd_opts)
    local args = vim.split(vim.trim(cmd_opts.args or ""), "%s+", { trimempty = true })
    local load_opts = {}
    local path = nil

    for _, arg in ipairs(args) do
      if arg == "all" or arg == "--all" or arg == "-a" then
        load_opts.all = true
      elseif not path then
        path = arg
      end
    end

    if path and path ~= "" then
      M.load_file(path, load_opts)
    else
      M.load_current_buffer(load_opts)
    end
  end, {
    nargs = "*",
    complete = "file",
    desc = "Load review findings JSON into diagnostics (usage: :CueReviewLoad [path] [all])",
  })

  vim.api.nvim_create_user_command("CueReviewClear", function()
    M.clear()
  end, {
    desc = "Clear all cue-review diagnostics",
  })

  vim.api.nvim_create_user_command("CueReviewQF", function()
    M.to_quickfix()
  end, {
    desc = "Populate Quickfix list with active review findings",
  })
end

return M
