{ config, pkgs, ... }:

{
  config = {
    home.username = "pl";
    home.homeDirectory = "/home/pl";
    home.stateVersion = "24.11";

    nixpkgs.config.allowUnfree = true;

    programs.home-manager.enable = true;

    modules.kitty.enable = true;
    modules.chrome.enable = true;
  };

  imports = [
    ../../programs/gui
    ../../programs/tui
  ];
}
