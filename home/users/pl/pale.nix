{ ... }:

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
      kitty.enable = true;
      ygt.enable = true;
    };
  };

  imports = [
    ../../programs/gui
    ../../programs/tui
  ];
}
