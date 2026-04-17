return {
  {
    "rcarriga/nvim-notify",
    enable = false,
    config = function()
      ---@diagnostic disable: missing-fields
      require 'notify'.setup({
        background_colour = "#192330",
        --max_width = 50,
        --max_height = 5,
        top_down          = false,
        render            = "compact"
      })
      ---@diagnostic enable: missing-fields

      vim.notify = require "notify"
    end,
  }
}
