{ config, pkgs, ... }:

{
  # home.packages = with pkgs; [ neovim ];
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraPackages = with pkgs; [
      notmuch
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
    ];

    extraWrapperArgs = [ "--suffix" "LD_LIBRARY_PATH" ":" "${pkgs.notmuch}/lib" ];
  };

  home.file."${config.xdg.configHome}/nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}
