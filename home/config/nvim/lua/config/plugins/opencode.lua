return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*", -- Latest stable release
    config = function()
      local oc = require("opencode")

      vim.g.opencode_opts = {
        server = {
          -- Use the port reachable from your terminal (you mentioned 52693 earlier)
          port = tonumber(vim.g.opencode_port) or 49000,

          -- Disable auto-start to prevent Neovim from trying to
          -- launch a local 'opencode' binary
          start = false,
        },

        prompts = {
          ["add_buffer"] = { prompt = "@buffer" },
          ["add_this"] = { prompt = "@this" },
          ["ask"] = { prompt = "", ask = true, submit = true },
          ["diagnostics"] = { prompt = "Explain @diagnostics", submit = true },
          ["diff"] = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
          ["document"] = { prompt = "Add comments documenting @this", submit = true },
          ["explain"] = { prompt = "Explain @this and its context", submit = true },
          ["implement"] = { prompt = "Implement only the following: @this", submit = true },
          ["fix"] = { prompt = "Fix @diagnostics", submit = true },
          ["optimize"] = { prompt = "Optimize @this for performance and readability", submit = true },
          ["pr:explain"] = { prompt = "/pr:explain", submit = true },
          ["pr:fusion-review"] = { prompt = "/pr:fusion-review", submit = true },
          ["review"] = { prompt = "Review @buffer for correctness and readability", submit = true },
          ["test"] = { prompt = "Add tests for @this", submit = true },
        }
      }

      vim.opt.autoread = true
    end
  }
}
