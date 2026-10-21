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
      # lua/config/plugins/conform.lua). The three python packages enable the
      # GFM / YAML frontmatter / footnote extensions, matching the nvf
      # "mdformat" selector used in the cast sandbox.
      mdformat
      python3Packages.mdformat-gfm
      python3Packages.mdformat-frontmatter
      python3Packages.mdformat-footnote
    ];

    extraWrapperArgs = [ "--suffix" "LD_LIBRARY_PATH" ":" "${pkgs.notmuch}/lib" ];
  };

  home.file."${config.xdg.configHome}/nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}
