{ config, pkgs, ... }:

{
  # home.packages = with pkgs; [ neovim ];
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraPackages = [ pkgs.notmuch ] ++ import ./nvim-tools.nix pkgs;

    extraWrapperArgs = [ "--suffix" "LD_LIBRARY_PATH" ":" "${pkgs.notmuch}/lib" ];
  };

  home.file."${config.xdg.configHome}/nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}
