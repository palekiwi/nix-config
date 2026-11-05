return {
  {
    "yousefakbar/notmuch.nvim",
    cond = vim.env.NVIM_NO_PERSONAL == nil,
    opts = {
      notmuch_db_path = "/home/pl/Maildir",
      sync = {
        sync_mode = "buffer"
      }
    },
  }
}
