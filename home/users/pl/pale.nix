{ ... }:

{
  imports = [
    ../../programs/gui
    ../../programs/tui
    ../../programs/local-tts
    ../../services
    ./sc-controller.nix
  ];

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
      oss.enable = true;
      spabreaks.enable = true;
    };

    services.handy = {
      enable = true;
    };

    services.cue-backup.enable = true;

    programs.sc-controller.enable = true;
    programs.local-tts = {
      enable = true;
      backend = "http";
      volume = 2.5;
    };
  };
}
