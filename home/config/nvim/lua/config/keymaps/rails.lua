local rails_utils = require('rails-utils')
local builtin = require('telescope.builtin')
local telescope_utils = require('config.utils.telescope')

local set = vim.keymap.set

local function find_files(dirs)
  builtin.find_files({ search_dirs = dirs })
end

local function grep_string_tailwind()
  builtin.grep_string {
    prompt_title = "Grep String: Tailwind",
    default_text = vim.fn.expand("<cfile>"),
    search_dirs = { "app/assets/tailwind/" },
    word_match = "-w"
  }
end

local function grep_string_sass()
  builtin.grep_string {
    prompt_title = "Grep String: Sass",
    default_text = vim.fn.expand("<cfile>"),
    search_dirs = { "webpack/src/styles/" },
    word_match = "-w"
  }
end

local function live_grep_specs()
  builtin.live_grep {
    prompt_title = "Live Grep: Specs",
    search_dirs = { "spec" },
  }
end

set("n", "<A-r>", rails_utils.find_template_render, { desc = "[Rails] Where is current view renedered?" })
set("n", "<A-t>", rails_utils.find_template, { desc = "[Rails] Find this template" })

-- set("n", "<leader>gt", grep_string_tailwind, { desc = "[Grep String] Tailwind" })
-- set("n", "<leader>gy", grep_string_sass, { desc = "[Grep String] Sass" })
-- set("n", "<space>gs", live_grep_specs, { desc = "[Live Grep] Specs" })
set("n", "<C-s>", rails_utils.alternate, { desc = "[Rails] Find Spec" })
set("n", "<leader>dd", rails_utils.show_diagnostics, { desc = "[Diagnostic] RSpec" })
set("n", "<leader>lr", "<cmd>LspRestart ruby_lsp stimulus_ls<cr>", { desc = "[LSP] Rails Restart" })

set("n", "<leader>ra", "<cmd>RspecRunnerAll<cr>", { desc = "[RSpec] Test All" })
set("n", "<leader>rp", "<cmd>RspecRunnerBase<cr>", { desc = "[RSpec] Test Base" })
set("n", "<leader>rf", "<cmd>RspecRunnerFailures<cr>", { desc = "[RSpec] Test Failures" })
set("n", "<leader>rl", "<cmd>RspecRunnerLast<cr>", { desc = "[RSpec] Repeat Last" })
set("n", "<leader>rn", "<cmd>RspecRunnerNearest<cr>", { desc = "[RSpec] Test Nearest" })
set("n", "<leader>rt", "<cmd>RspecRunnerFile<cr>", { desc = "[RSpec] Test File" })
set("n", "<leader>rr", "<cmd>RspecRunnerShowResults<cr>", { desc = "[RSpec] Results" })
set("n", "<leader>rc", "<cmd>RspecRunnerCancel<cr>", { desc = "[RSpec] Cancel Run" })
set("n", "<leader>rda", "<cmd>RspecRunnerTermAll<cr>", { desc = "[RSpec] Terminal All" })
set("n", "<leader>rdp", "<cmd>RspecRunnerTermBase<cr>", { desc = "[RSpec] Terminal Base" })
set("n", "<leader>rdt", "<cmd>RspecRunnerTermFile<cr>", { desc = "[RSpec] Terminal File" })
set("n", "<leader>rdn", "<cmd>RspecRunnerTermNearest<cr>", { desc = "[RSpec] Terminal Nearest" })
set("n", "<leader>rdf", "<cmd>RspecRunnerTermFailures<cr>", { desc = "[RSpec] Terminal Failures" })
set("n", "<leader>rdl", "<cmd>RspecRunnerTermLast<cr>", { desc = "[RSpec] Terminal Last" })
set("n", "<C-l>", "<cmd>RspecRunnerShowResults<cr>", { desc = "[RSpec] Results" })

set("n", "<leader>sC", function() telescope_utils.changed_files("app/contracts") end, { desc = "Contracts" })
set("n", "<leader>sS", function() telescope_utils.changed_files("app/services") end, { desc = "Services" })
set("n", "<leader>sc", function() telescope_utils.changed_files("app/controllers") end, { desc = "Controllers" })
set("n", "<leader>se", function() telescope_utils.changed_files("webpack/src/components/elm") end, { desc = "Elm" })
set("n", "<leader>sp", function() telescope_utils.changed_files("app/presenters") end, { desc = "Presenters" })
set("n", "<leader>sr", function() telescope_utils.changed_files("app/services") end, { desc = "Services" })
set("n", "<leader>ss", function() telescope_utils.changed_files("spec/") end, { desc = "Specs" })
set("n", "<leader>st", function() telescope_utils.changed_files("webpack/src/controllers") end, { desc = "Stimulus" })
set("n", "<leader>sv", function() telescope_utils.changed_files("app/views") end, { desc = "Views" })
set("n", "<leader>sy", function() telescope_utils.changed_files("webpack/src/styles") end, { desc = "Styles" })

set("n", "<leader>sF", function() find_files({ "config/initializers/feature_switches" }) end, { desc = "Contracts" })

set("n", "<leader>SC", function() telescope_utils.grep_changed_files("app/contracts") end, { desc = "Contracts" })
set("n", "<leader>SS", function() telescope_utils.grep_changed_files("app/services") end, { desc = "Services" })
set("n", "<leader>Sc", function() telescope_utils.grep_changed_files("app/controllers") end, { desc = "Controllers" })
set("n", "<leader>Se", function() telescope_utils.grep_changed_files("webpack/src/components/elm") end, { desc = "Elm" })
set("n", "<leader>Sp", function() telescope_utils.grep_changed_files("app/presenters") end, { desc = "Presenters" })
set("n", "<leader>Sr", function() telescope_utils.grep_changed_files("app/services") end, { desc = "Services" })
set("n", "<leader>Ss", function() telescope_utils.grep_changed_files("spec/") end, { desc = "Specs" })
set("n", "<leader>St", function() telescope_utils.grep_changed_files("webpack/src/controllers") end,
  { desc = "Stimulus" })
set("n", "<leader>Sv", function() telescope_utils.grep_changed_files("app/views") end, { desc = "Views" })
set("n", "<leader>Sy", function() telescope_utils.grep_changed_files("webpack/src/styles") end, { desc = "Styles" })
