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

    services.cube-remote.enable = false;

    programs.sc-controller.enable = true;
    programs.local-tts = {
      enable = true;
      backend = "http";
      volume = 1.5;
      target = "bluez_output.11_75_58_93_13_9F.1";
      bridge.enable = true;
      bridge.natsUrl = "nats://127.0.0.1:4222";
      bridge.leadingSilenceMs = 1000;
      cubeControl.enable = true;
      cubeControl.gotify.enable = true;
    };
  };
}
