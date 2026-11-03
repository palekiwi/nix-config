pkgs:
with pkgs; [
  # Markdown structural formatter for conform.nvim (see
  # lua/config/plugins/conform.lua), wrapped the same way nvf's
  # "mdformat" selector does: one python3 env bundling mdformat plus
  # its GFM / YAML-frontmatter / footnote parser plugins. Without the
  # single env, the bare mdformat binary cannot import the plugins and
  # mangles frontmatter (parses the `---` block as setext headings).
  (python3.withPackages (ps: with ps; [
    mdformat
    mdformat-gfm
    mdformat-frontmatter
    mdformat-footnote
  ]))
  curl
  gcc
  gnumake
  go
  lua-language-server
  nixd
  nixpkgs-fmt
  nodejs_24
  prettier
  taplo
  tree-sitter
  typescript-language-server
  unzip
  vscode-langservers-extracted
]
