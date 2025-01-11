{ config, pkgs, ... }:

{
  config = {
    home.username = "pl";
    home.homeDirectory = "/home/pl";
    home.stateVersion = "24.11";

    nixpkgs.config.allowUnfree = true;

    programs.home-manager.enable = true;

    modules.kitty.enable = false;

    # kitty is installed from Fedora packages
    home.file."${config.xdg.configHome}/kitty" = {
      source = ../../config/kitty;
      recursive = true;
    };
  };

  imports = [
    ../../programs/gui
    ../../programs/tui
  ];
}
