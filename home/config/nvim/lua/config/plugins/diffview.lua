return {
  {
    "sindrets/diffview.nvim",
    config = function()
      require 'diffview'.setup {
        use_icons = true,
        enhanced_diff_hl = true,
        file_panel = {
          win_config = {
            position = "bottom",
            width = 35,
            height = 20,
          },
        },
        key_bindings = {
          view = {
            ["tn"] = "<cmd>DiffviewToggleFiles<cr>",
          },
          file_panel = {
            ["tn"] = "<cmd>DiffviewToggleFiles<cr>",
          },
        },
      }
    end
  }
}
