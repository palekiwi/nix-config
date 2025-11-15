{ ... }:

{
  imports = [
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

    gui = false;  # Disable GUI applications for headless server

    modules = {
      oss.enable = true;
      spabreaks.enable = true;
    };
  };
}
