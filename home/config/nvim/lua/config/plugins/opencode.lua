return {
  {
    'NickvanDyke/opencode.nvim',
    commit = "c7594f8",
    dependencies = {
      { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
    },
    config = function()
      local oc = require("opencode")

      vim.g.opencode_opts = {

        -- on_opencode_not_found = function() vim.print("[Opencode]: Server not found") end,

        -- load port from an var set on a project basis or use a custom default
        port = tonumber(vim.g.opencode_port) or 49000,

        prompts = {
          ["add_buffer"] = { prompt = "@buffer" },
          ["add_this"] = { prompt = "@this" },
          ["ask"] = { prompt = "", ask = true, submit = true },
          ["diagnostics"] = { prompt = "Explain @diagnostics", submit = true },
          ["diff"] = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
          ["document"] = { prompt = "Add comments documenting @this", submit = true },
          ["explain"] = { prompt = "Explain @this and its context", submit = true },
          ["fix"] = { prompt = "Fix @diagnostics", submit = true },
          ["optimize"] = { prompt = "Optimize @this for performance and readability", submit = true },
          ["pr:explain"] = { prompt = "/pr:explain", submit = true },
          ["pr:fusion-review"] = { prompt = "/pr:fusion-review", submit = true },
          ["review"] = { prompt = "Review @buffer for correctness and readability", submit = true },
          ["test"] = { prompt = "Add tests for @this", submit = true },
        }
      }

      vim.opt.autoread = true

      local keymaps = {
        { "n",          "<space>a",  function() oc.ask() end,                                                      "Ask opencode", },
        { "n",          "<space>et", function() oc.prompt("Explain @this and its context", { submit = true }) end, "Explain this" },
        { { "n", "v" }, "<space>i",  function() oc.ask("@this: ", { submit = true }) end,                          "Ask about this" },
        { "n",          "<space>f",  function() oc.ask("@buffer: ", { submit = true }) end,                        "Ask about buffer" },
        { "n",          "<space>d",  function() oc.ask("@diff: ", { submit = true }) end,                          "Ask about diff" },
        { "n",          "<space>n",  function() oc.command("session_new") end,                                     "New session" },
        { "n",          "<space>+",  function() oc.prompt("@this") end,                                            "Add this" },
        { "n",          "<space>pe", function() oc.prompt("/pr:explain", { submit = true }) end,                   "PR: Explain" },
        { "n",          "<space>pr", function() oc.prompt("/pr:fusion-review", { submit = true }) end,             "PR: Fusion Review" },
        { "n",          "<space>s",  function() oc.select() end,                                                   "Select prompt" },
        { "n",          "<space>y",  function() oc.command("messages_copy") end,                                   "Copy last message" },
      }

      for _, m in ipairs(keymaps) do
        vim.keymap.set(m[1], m[2], m[3], { desc = m[4] })
      end
    end
  }
}
