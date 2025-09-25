local entry_display = require "telescope.pickers.entry_display"
local make_entry = require "telescope.make_entry"

M = {}

M.gen_from_git_commits = function(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 10 },
      { width = 10 },
      { width = 21 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      { entry.value,  "TelescopeResultsComment" },
      { entry.date,   "TelescopePreviewDate" },
      { entry.author, "TelescopePreviewUser" },
      { entry.msg,    "TelescopePreviewMessage" }
    }
  end

  return function(entry)
    if entry == "" then
      return nil
    end

    local sha, date_, time, _, rest = string.match(entry, "([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) (.*)")
    local author = string.sub(rest, 1, 21)
    local msg = string.gsub(string.sub(rest, 22), "^%s+", "")

    local date ---@type string
    if date_ == os.date("%Y-%m-%d") then
      date = time
    else
      date = date_
    end

    return make_entry.set_default_entry_mt({
      value = sha,
      ordinal = sha .. " " .. date .. " " .. author .. " " .. msg,
      date = date,
      author = author,
      msg = msg,
      display = make_display,
      current_file = opts.current_file,
    }, opts)
  end
end

M.gen_from_pr_commits = function(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 10 },
      { width = 10 },
      { width = 21 },
      { width = 6 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      { entry.value,  "TelescopeResultsComment" },
      { entry.date,   "TelescopePreviewDate" },
      { entry.author, "TelescopePreviewUser" },
      { entry.number, "TelescopeResultsComment" },
      { entry.msg,    "TelescopePreviewMessage" }
    }
  end

  return function(entry)
    if entry == "" then
      return nil
    end

    local sha, date_, time, _, rest = string.match(entry, "([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) (.*)")
    local author = string.sub(rest, 1, 21)
    local number, msg = string.sub(rest, 22):match("Merge pull request (#%d+) from [^%s]+ (.+)")

    number = number or string.sub(rest, 22):match("Merge pull request (#%d+).*")
    msg = msg or ""

    local date ---@type string
    if date_ == os.date("%Y-%m-%d") then
      date = time
    else
      date = date_
    end

    return make_entry.set_default_entry_mt({
      value = sha,
      ordinal = sha .. " " .. date .. " " .. author .. " " .. number .. " " .. msg,
      date = date,
      author = author,
      msg = msg,
      number = number,
      display = make_display,
      current_file = opts.current_file,
    }, opts)
  end
end


return M
