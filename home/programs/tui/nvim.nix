{ config, pkgs, ... }:

{
  # home.packages = with pkgs; [ neovim ];
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      notmuch
    ];

    extraWrapperArgs = [ "--suffix" "LD_LIBRARY_PATH" ":" "${pkgs.notmuch}/lib" ];
  };

  home.file."${config.xdg.configHome}/nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}
