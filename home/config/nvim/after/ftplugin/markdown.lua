vim.bo.shiftwidth = 2
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.number = false
vim.opt_local.relativenumber = false

-- Repurpose `gc` (the built-in `vim._comment` operator) as a blockquote toggle:
-- prefix lines with "> ". Markdown's stock commentstring is "<!-- %s -->", which
-- is near-useless in prose; blockquotes are far more common.
--
-- This MUST live in `after/ftplugin/` (not `ftplugin/`): the host's config dir
-- precedes `VIMRUNTIME` in 'runtimepath', so anything set in `ftplugin/` is
-- reset by the stock `VIMRUNTIME/ftplugin/markdown.vim` (which hard-codes
-- `<!-- %s -->`). `after/` is sourced after `VIMRUNTIME`, so this wins.
--
-- The built-in commenter (`vim._comment`) also looks up the filetype-level
-- default via `vim.filetype.get_option("markdown", "commentstring")` whenever a
-- markdown treesitter parser is active (nvim 0.11+ bundles one). That lookup
-- re-sources every ftplugin in a scratch buffer, including `after/`, so placing
-- the override here fixes both the buffer-local value and the filetype default.
vim.bo.commentstring = "> %s"
