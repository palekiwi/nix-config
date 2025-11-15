{ ... }:

{
  imports = [
    ../../programs/gui
    ../../programs/tui
  ];

  config = {
    home = {
      username = "pl";
      homeDirectory = "/home/pl";
      stateVersion = "25.05";
    };

    nixpkgs.config.allowUnfree = true;
    programs.home-manager.enable = true;

    modules = {
      chrome.enable = true;
      kitty.enable = true;
      oss.enable = true;
      spabreaks.enable = true;
    };
  };
}
