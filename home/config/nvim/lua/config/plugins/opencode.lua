return {
  {
    'NickvanDyke/opencode.nvim',
    dependencies = {
      { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
    },
    config = function()
      local oc = require("opencode")

      vim.g.opencode_opts = {

        on_opencode_not_found = function() vim.print("[Opencode]: Server not found") end,

        -- load port from an var set on a project basis or use a custom default
        port = tonumber(vim.g.opencode_port) or 49000,
        -- prompts = {}
      }

      vim.opt.autoread = true

      local opts = { submit = true }
      local keymaps = {
        { "n", "<space>a",  function() oc.ask() end,                                         'Ask opencode', },
        { "n", "<space>et", function() oc.prompt("Explain @this and its context", opts) end, "Explain this" },
        { "n", "<space>i",  function() oc.ask("@this: ", opts) end,                          "Ask about this" },
        { "n", "<space>f",  function() oc.ask("@buffer: ", opts) end,                        "Ask about buffer" },
        { "n", "<space>d",  function() oc.ask("@diff: ", opts) end,                          "Ask about diff" },
        { "n", "<space>n",  function() oc.command("session_new") end,                        "New session" },
        { "n", "<space>o+", function() oc.prompt("@this") end,                               "Add this" },
        { "n", "<space>pe", function() oc.prompt('/pr:explain', opts) end,                   'PR: Explain' },
        { "n", "<space>pr", function() oc.prompt('/pr:fusion-review', opts) end,             'PR: Fusion Review' },
        { "n", "<space>rb", function() oc.prompt('Fix: @diagnostics') end,                   'Fix diagnostics' },
        { "n", "<space>s",  function() oc.select() end,                                      "Select prompt" },
        { "n", "<space>y",  function() oc.command('messages_copy') end,                      'Copy last message' },
      }

      for _, m in ipairs(keymaps) do
        vim.keymap.set(m[1], m[2], m[3], { desc = m[4] })
      end
    end
  }
}
