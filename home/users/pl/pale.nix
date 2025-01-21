{ config, ... }:

{
  config = {
    home = {
      username = "pl";
      homeDirectory = "/home/pl";
      stateVersion = "24.11";
    };

    nixpkgs.config.allowUnfree = true;

    programs.home-manager.enable = true;

    modules = {
      chrome.enable = true;
      kitty.enable = false;
      ygt.enable = true;
    };

    fedora = true;

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
