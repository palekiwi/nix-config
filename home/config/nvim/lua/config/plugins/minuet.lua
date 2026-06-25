return {
  {
    'milanglacier/minuet-ai.nvim',
    enable = false,
    config = function()
      require('minuet').setup {
        -- provider =  'gemini'
      }
    end,
  }
}
