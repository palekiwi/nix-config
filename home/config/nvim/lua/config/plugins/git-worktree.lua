return {
  {
    "polarmutex/git-worktree.nvim",
    version = "^2",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      local Hooks = require("git-worktree.hooks")

      -- Load the Telescope extension
      require("telescope").load_extension("git_worktree")

      -- Example Hook: Switch directory & notify when changing worktrees
      Hooks.register(Hooks.type.SWITCH, function(path, prev_path)
        vim.notify("Switched from " .. prev_path .. " to " .. path)
      end)
    end,
    keys = {
      {
        "<leader>gws",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Switch / Delete Worktrees",
      },
    },
  }
}
