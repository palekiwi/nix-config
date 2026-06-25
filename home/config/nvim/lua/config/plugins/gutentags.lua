return {
  {
    "ludovicchabant/vim-gutentags",
    --  turned out this causes IO bottleneck
    --  TODO: figure out a solution to run only for explicitly enabled repos
    --  or look for an alternative
    enabled = false
  }
}
