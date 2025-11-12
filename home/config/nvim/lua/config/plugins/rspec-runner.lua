return {
  {
    "palekiwi/rspec-runner.nvim",
    dev = false,
    branch = "dev",
    config = function()
      require 'rspec-runner'.setup({
        defaults =  {
          notify = true,
          git_base = function() return vim.g.git_base end,
        },
        projects = {
          -- {
          --   path = "/home/pl/code/ygt/spabreaks",
          --   cmd = function(rspec_flags, files)
          --     local args = vim.list_extend(rspec_flags, files)
          --
          --     return vim.list_extend(
          --       { "docker-compose", "exec", "-it", "test", "bundle", "exec", "rspec" },
          --       args
          --     )
          --   end,
          -- },
          -- {
          --   path = "/home/pl/code/ygt/sb%-voucher%-redemptions",
          --   cmd = function(rspec_flags, files)
          --     local args = vim.list_extend(rspec_flags, files)
          --
          --     return vim.list_extend(
          --       { "docker-compose", "exec", "-it", "test", "bundle", "exec", "rspec", "--require", "app.rb"},
          --       args
          --     )
          --   end,
          -- },
          -- {
          --   path = "/home/pl/code/ygt/.*",
          --   cmd = { "docker-compose", "exec", "-it", "test", "bundle", "exec", "rspec" },
          -- },
        }
      })
    end,
  }
}
