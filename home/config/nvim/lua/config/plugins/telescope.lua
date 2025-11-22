return {
  {
    "nvim-telescope/telescope-ui-select.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },
    config = function()
      local actions = require("telescope.actions")
      local actions_layout = require("telescope.actions.layout")

      require("telescope").setup {
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
            }
          }
        },
        defaults = {
          mappings = {
            i = {
              ["<C-a>"] = actions.cycle_previewers_prev,
              ["<C-p>"] = actions_layout.toggle_preview,
              ["<C-s>"] = actions.cycle_previewers_next,
            }
          },
          sorting_strategy = "ascending",
          layout_strategy = "flex",
          layout_config = {
            horizontal = {
              height = 0.9,
              preview_cutoff = 120,
              prompt_position = "top",
              width = 0.9
            },
            vertical = {
              height = 0.95,
              mirror = true,
              prompt_position = "top",
              preview_cutoff = 0,
              preview_height = 0.65,
              width = 0.95
            }
          }
        }
      }
      --- To get ui-select loaded and working with telescope, you need to call
      --- load_extension, somewhere after setup function:
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("fzf")
    end,
  }
}
