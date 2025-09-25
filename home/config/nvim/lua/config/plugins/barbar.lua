return {
  {
    "romgrk/barbar.nvim",
    config = function()
      require 'barbar'.setup {
        animation = false,
        closeable = true,
        icons = {
          separator = {
            left = '',
            right = ''
          }
        }
      }
    end
  }
}
