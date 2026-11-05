-- Ansible managed: templates/lua/config/settings.lua.j2 modified on 2023-07-20 19:06:46 by pl on dev.ctn
local set = vim.opt
local setup_autocmd = require("config.setup.autocmd")
local setup_filetypes = require("config.setup.filetypes")
local setup_highlights = require("config.setup.highlights")

set.shell = "/usr/bin/env bash"
set.termguicolors = true

set.title = true
set.titlestring = "[vim] %t (%{expand('%:p:h')})"

set.expandtab = true
set.smarttab = true
set.shiftwidth = 4
set.tabstop = 4

set.hlsearch = true
set.incsearch = true
set.ignorecase = true
set.smartcase = true

set.splitbelow = true
set.splitright = true
set.wrap = false
set.linebreak = true
set.scrolloff = 5
set.fileencoding = 'utf-8'

set.number = true
set.relativenumber = false
set.cursorline = false

set.laststatus = 3

set.timeout = true
set.timeoutlen = 300

set.hidden = true
set.completeopt = 'menuone,noselect'

set.foldlevel = 99
set.foldmethod = "indent"
set.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.api.nvim_set_option_value("clipboard", "unnamed", {})

if os.getenv("NVIM_CLIPBOARD_OSC52") == "1" then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') }
  end
  vim.g.clipboard = {
    name = "OSC 52 (copy only)",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end

vim.diagnostic.config({
  virtual_text = false,
  foat = true,
})

setup_autocmd()
setup_filetypes()
setup_highlights()
