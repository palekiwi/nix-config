local wk = require("which-key")
local kiwi = require('kiwi')
require("config.keymaps.rails")
local keymaps_telescope = require("config.keymaps.telescope")

local agents_utils = require('config.utils.agents')
local ctx_clipboard = require('config.utils.context_clipboard')
local gh_utils = require('config.utils.gh')
local git_utils = require('config.utils.git')
local helpers = require('config.utils.helpers')
local hunk_comments = require('config.utils.hunk-comments')
local nvim_utils = require('config.utils.nvim')
local qf_utils = require('config.utils.quickfix')
local telescope_utils = require('config.utils.telescope')

local set = vim.keymap.set

set({ 'n', 'v' }, '<Down>', 'gj')
set({ 'n', 'v' }, '<Up>', 'gk')

vim.keymap.set('n', 'h', ']c')
vim.keymap.set('n', 'H', '[c')

vim.api.nvim_set_keymap('v', '<C-C>', '"+y', { noremap = true, silent = true })

-- Set the default step size to 5
vim.keymap.set('n', '<C-w>m', '40<C-w>>', { noremap = true })
vim.keymap.set('n', '<C-w>M', '40<C-w><', { noremap = true })

local base = {
  -- buffers
  { "<A-,>",             "<cmd>BufferPrevious<cr>",                                              desc = "Previous Buffer" },
  { "<A-.>",             "<cmd>BufferNext<cr>",                                                  desc = "Next Buffer" },
  { "<A-<>",             "<cmd>BufferMovePrevious<cr>",                                          desc = "Move Previous Buffer" },
  { "<A->>",             "<cmd>BufferMoveNext<cr>",                                              desc = "Move Next Buffer" },
  { "<A-X>",             "<cmd>BufferCloseAllButCurrent<cr>",                                    desc = "Close Buffer All But Current" },
  -- quickfix list
  { "<A-Left>",          "<cmd>cfirst<cr>",                                                      desc = "[Qflist] First" },
  { "<A-Up>",            "<cmd>cprev<cr>",                                                       desc = "[Qflist] Prev" },
  { "<A-Down>",          "<cmd>cnext<cr>",                                                       desc = "[Qflist] Next" },
  { "<A-PageUp>",        "<cmd>lprev<cr>",                                                       desc = "[Loclist] Prev" },
  { "<A-PageDown>",      "<cmd>lnext<cr>",                                                       desc = "[Loclist] Next" },
  -- mod
  { "<space>r",          telescope_utils.file_review,                                            desc = "File review" },
  { "<A-a>",             "<cmd>Trouble<cr>",                                                     desc = "[Agents] Find files" },
  { "<A-s>",             agents_utils.find_files,                                                desc = "[Agents] Find files" },
  { "<A-t>",             function() agents_utils.find_files({ latest = true }) end,              desc = "[Agents] Find latest files" },
  { "<A-d>",             telescope_utils.diffview_since,                                         desc = "Search changed files" },
  { "<A-f>",             "<cmd>Telescope live_grep<cr>",                                         desc = "Live Grep" },
  { "<A-l>",             "<cmd>set cursorline!<cr>",                                             desc = "Toggle Cursorline" },
  { "<A-m>",             "zMzA",                                                                 desc = "Toggle Fold" },
  { "<A-p>",             telescope_utils.changed_files_since,                                    desc = "Search changed files" },
  { "<A-u>",             "<Plug>CapsLockToggle",                                                 desc = "Toggle Capslock",              mode = "i" },
  { "<A-w>",             telescope_utils.search_cword,                                           desc = "Live Grep" },
  { "<A-x>",             "<cmd>BufferClose<cr>",                                                 desc = "Close Buffer All But Current" },
  { "<A-z>",             "za",                                                                   desc = "Toggle Fold" },
  { "<C-b>",             "<cmd>Telescope buffers ignore_current_buffer=false sort_mru=true<cr>", desc = "Buffers" },
  { "<C-d>",             telescope_utils.diagnostics,                                            desc = "[LSP] diagnostics" },
  { "<C-e>",             "<cmd>Telescope oldfiles cwd_only=true<cr>",                            desc = "Recent Files" },
  { "<C-f>",             "<cmd>Telescope find_files hidden=true<cr>",                            desc = "Find File" },
  { "<C-p>",             telescope_utils.changed_files,                                          desc = "Search changed files" },
  { "<C-q>",             "<cmd>Telescope quickfix show_line=false<cr>",                          desc = "Quickfix" },
  { "<C-u>",             telescope_utils.lsp_references,                                         desc = "Ref" },
  { "<C-w>h",            "<cmd>hide<cr>",                                                        desc = "Hide" },
  { "<Esc><Esc>",        "<C-\\><C-n>",                                                          desc = "Exit termina mode",            mode = "t" },
  -- F keys
  { "<F4>",              "<C-R>=strftime('%T')<cr>",                                             desc = "Insert time",                  mode = "i" },
  { "<F5>",              "<C-R>=strftime('%Y-%m-%d %a')<cr>",                                    desc = "Insert date with weekday",     mode = "i" },
  { "<F6>",              "<C-R>=strftime('%F')<cr>",                                             desc = "Insert date",                  mode = "i" },
  { "<F8>",              "<C-R>=expand('%:t')<cr>",                                              desc = "Insert current filename",      mode = "i" },
  -- no leader
  { "T",                 kiwi.todo.toggle,                                                       desc = "Toggle Todo" },
  { "W",                 "<cmd>HopWord<cr>",                                                     desc = "Hop Word",                     mode = "n" },
  { "g",                 group = "go to" },
  { "gc",                vim.lsp.buf.declaration,                                                desc = "[LSP] Go to Declaration" },
  { "gd",                vim.lsp.buf.definition,                                                 desc = "[LSP] Go to Definition" },
  { "gi",                vim.lsp.buf.implementation,                                             desc = "[LSP] Go to Implementation" },
  { "gr",                vim.lsp.buf.references,                                                 desc = "[LSP] Go to References" },
  { "gt",                vim.lsp.buf.type_definition,                                            desc = "[LSP] Go to Type Definition" },
  { "l",                 "<cmd>HopLineStart<cr>",                                                desc = "Hop Line Start",               mode = { "n", "v" } },
  { "s",                 "<cmd>HopChar1<cr>",                                                    desc = "Hop Char 1",                   mode = { "n", "v" } },
  -- BS
  { "<BS>n",             function() git_utils.toggle_git_tree("focus") end,                      desc = "Tree: Git status" },
  { "<BS>0",             function() git_utils.set_base_branch("HEAD") end,                       desc = "Change base: HEAD~1" },
  { "<BS>1",             function() git_utils.set_base_branch("HEAD~1") end,                     desc = "Change base: HEAD~1" },
  { "<BS>2",             function() git_utils.set_base_branch("HEAD~2") end,                     desc = "Change base: HEAD~2" },
  { "t",                 group = "toggle" },
  { "th",                "<cmd>DiffviewOpen HEAD<cr>",                                           desc = "DiffviewOpen" },
  { "tI",                "<cmd>DiffviewClose<cr>",                                               desc = "DiffviewClose" },
  { "tN",                "<cmd>DiffviewClose<cr>",                                               desc = "DiffviewClose" },
  { "tb",                "<cmd>Gitsigns toggle_current_line_blame<cr>",                          desc = "Blame" },
  { "tc",                "<cmd>DiffviewOpen<cr>",                                                desc = "DiffviewOpen" },
  { "te",                function() git_utils.set_base_branch() end,                             desc = "Change base: From Environment" },
  { "tf",                function() git_utils.diffview_file_history(true) end,                   desc = "DiffviewFileHistory" },
  { "tF",                git_utils.diffview_file_history,                                        desc = "DiffviewFileHistory" },
  { "tH",                "<cmd>Gitsigns preview_hunk_inline<cr>",                                desc = "Deleted" },
  { "ti",                function() git_utils.diffthis(true) end,                                desc = "Diff this: vertical" },
  { "tl",                "<cmd>nohlsearch<cr>",                                                  desc = "Hunks to Loclist" },
  { "<BS>m",             function() git_utils.set_base_branch(vim.g.git_master) end,             desc = "Change base: master" },
  { "tn",                git_utils.diffview_this,                                                desc = "Diff this: horizontal" },
  { "tq",                git_utils.hunks_to_loclist,                                             desc = "Hunks to Loclist" },
  { "tq",                helpers.toggle_quickfix,                                                desc = "Toggle quickfix" },
  { "tr",                nvim_utils.toggle_relativenumber,                                       desc = "Toggle relativenumber" },
  { "tw",                nvim_utils.toggle_wrap,                                                 desc = "Toggle Wrap" },
  { "ty",                function() git_utils.set_base_branch(vim.fn.getreg("+")) end,           desc = "Change base: master" },
  -- leader
  { "<leader><space>",   helpers.open_on_line,                                                   desc = "Open file on line" },
  { "<leader>N",         function() git_utils.toggle_git_tree("show") end,                       desc = "Tree: Git status" },
  { "<leader>a",         vim.lsp.buf.code_action,                                                desc = "LSP Code Action" },
  { "<leader>b",         "<cmd>Neotree toggle show buffers left<cr>",                            desc = "tree toggle" },
  { "<leader>d",         group = "[Diagnostic]" },
  { "<leader>df",        vim.diagnostic.open_float,                                              desc = "[Diagnostic] float" },
  { "<leader>dn",        function() vim.diagnostic.jump({ count = 1, float = true }) end,        desc = "[Diagnostic] next" },
  { "<leader>dp",        function() vim.diagnostic.jump({ count = -1, float = true }) end,       desc = "[Diagnostic] prev" },
  { "<leader>eg",        telescope_utils.search_tags_cword,                                      desc = "Find tag" },
  { "<leader>eh",        "<cmd>Telescope help_tags<cr>",                                         desc = "Help tags" },
  { "<leader>es",        "<cmd>Telescope current_buffer_tags show_line=true<cr>",                desc = "Tags" },
  { "<leader>et",        telescope_utils.search_tags,                                            desc = "Search tags" },
  { "<leader><leader>c", agents_utils.create_commit_dir,                                         desc = "[Agents] Spec.md" },
  { "<leader><leader>s", agents_utils.create_spec,                                               desc = "[Agents] Spec.md" },
  { "<leader>fq",        qf_utils.add_cursor_to_qf,                                              desc = "Add to quickfix" },
  { "<leader>fQ",        "<cmd>cexpr []<cr>",                                                    desc = "Clear quickfix" },
  { "<leader>g",         group = "[Git]" },
  { "<leader>gh",        hunk_comments.show,                                                     desc = "Hunk comments" },
  { "<leader>gH",        function() hunk_comments.show({ all = true }) end,                      desc = "Hunk comments for all files" },
  { "<leader>ga",        telescope_utils.git_commits,                                            desc = "[Telescope] All commits" },
  { "<leader>gb",        git_utils.diffview_blame,                                               desc = "Diffview blame line" },
  { "<C-h>",             telescope_utils.git_pr_commits,                                         desc = "[Telescope] Branch commits" },
  { "<leader>gm",        telescope_utils.git_pr_merge_commits,                                   desc = "[Telescope] PR Merge commits" },
  { "<leader>gp",        telescope_utils.grep_changed_files,                                     desc = "Live Grep in changed files" },
  { "<leader>gr",        "<cmd>Gitsigns reset_hunk<cr>",                                         desc = "[Gitsigns] Reset Hunk" },
  { "<leader>gs",        "<cmd>Gitsigns show<cr>",                                               desc = "[Gitsigns] Show" },
  { "<leader>h",         "<cmd>Gitsigns toggle_deleted<cr><cmd>Gitsigns toggle_word_diff<cr>",   desc = "Git: Preview inline" },
  { "<leader>l",         group = "[LSP]" },
  { "<leader>li",        "<cmd>LspInfo<cr>",                                                     desc = "LSP: Info" },
  { "<leader>ll",        "<cmd>LspLog<cr>",                                                      desc = "LSP: Log" },
  { "<leader>m",         "<cmd>Himalaya<cr>",                                                    desc = "Himalaya" },
  { "<leader>q",         "<cmd>quit<cr>",                                                        desc = "quit" },
  { "<leader>t",         "<cmd>Neotree toggle position=left<cr>",                                desc = "tree toggle" },
  { "<leader>w",         "<cmd>write<cr>",                                                       desc = "write" },
  { "<leader>y",         group = "Copy to clipboard" },
  { "<leader>ygb",       function() gh_utils.copy_file_url({ branch = vim.g.git_base }) end,     desc = "GH file: base" },
  { "<leader>ygc",       gh_utils.copy_files_changed_url,                                        desc = "GH files changed" },
  { "<leader>ygd",       gh_utils.copy_diff_url,                                                 desc = "GH diff" },
  { "<leader>ygf",       gh_utils.copy_file_url,                                                 desc = "GH file: current" },
  { "<leader>ygh",       gh_utils.copy_blame_hash_short,                                         desc = "GH file: short hash" },
  { "<leader>ygm",       function() gh_utils.copy_file_url({ branch = "master" }) end,           desc = "GH file: master" },
  { "<leader>ygp",       function() gh_utils.copy_file_url({ branch = vim.fn.getreg("+") }) end, desc = "GH file: clipboard" },
  { "<leader>yf",        function() ctx_clipboard.copy_file_path(false) end,                     desc = "File path" },
  { "<leader>C",         function() ctx_clipboard.copy_file_path(false) end,                     desc = "File path" },
  { "<leader>c",         function() ctx_clipboard.copy_file_path(true) end,                      desc = "File path with cursor" },
  { "<leader>c",         ctx_clipboard.copy_file_with_visual_range,                              desc = "File with visual range",       mode = "v" },
  { "<leader>yd",        ctx_clipboard.copy_diagnostic_on_line,                                  desc = "Diagnostic on line" },
  { "<leader>yD",        ctx_clipboard.copy_diagnostics_for_file,                                desc = "All file diagnostics" },
}

set("n", "<leader>x", "<cmd>.lua<CR>", { desc = "Execute the current line" })
set("n", "<leader><leader>x", "<cmd>source %<CR>", { desc = "Execute the current file" })

local noop = {
  { "s", "s", desc = "No Op", mode = "s" }, -- prevent changing mode in snippet expansion
  { "l", "l", desc = "No Op", mode = "s" }, -- prevent changing mode in snippet expansion
}

wk.add(base)
wk.add(noop)

wk.add(keymaps_telescope)

wk.setup({})
