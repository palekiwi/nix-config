return {
  {
    'NickvanDyke/opencode.nvim',
    dependencies = {
      { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
    },
    config = function()
       vim.g.opencode_opts = {
        -- load port from an var set on a project basis or use a custom default
        port = tonumber(vim.g.opencode_port) or 49000,
      }
    end,
    keys = {
      -- Recommended keymaps
      { '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end, desc = 'Scroll messages down', },
      { '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end, desc = 'Scroll messages up', },
      { '<space>a', function() require('opencode').ask() end, desc = 'Ask opencode', },
      { '<space>ec', function() require('opencode').prompt("Explain @cursor and its context") end, desc = "Explain code near cursor", },
      { '<space>ep', function() require('opencode').command('pr:explain') end, desc = 'PR: Explain', },
      { '<space>er', function() require('opencode').command('pr:fusion-review') end, desc = 'PR: Fusion Review', },
      { '<space>n', function() require('opencode').command('session_new') end, desc = 'New session', },
      { '<space>p', function() require('opencode').select() end, desc = 'Select prompt', mode = { 'n', 'v', }, },
      { '<space>i', function() require('opencode').ask('@selection: ') end, desc = 'Ask opencode about selection', mode = 'v', },
      { '<space>i', function() require('opencode').ask('@cursor: ') end, desc = 'Ask at cursor', mode = 'n', },
      { '<space>f', function() require('opencode').ask('@buffer: ') end, desc = 'Ask about buffer', mode = 'n', },
      { '<space>y', function() require('opencode').command('messages_copy') end, desc = 'Copy last message', },
      { '<space>rb', function() require('opencode').prompt('Fix: @diagnostics ') end, desc = 'Fix diagnostics', },
    },
  }
}
