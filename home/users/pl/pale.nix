{ ... }:

{
  imports = [
    ../../programs/gui
    ../../programs/tui
    ../../services
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

    programs.sc-controller = {
      enable = true;
      buttons = {
        A = [ "KEY_ENTER" ];
        B = [ "KEY_ESC" ];
        X = [ "KEY_BACKSPACE" ];
        Y = [ "KEY_SPACE" ];
        DOTS = [ "KEY_PAUSE" ];
        LGRIP = [ "BTN_LEFT" ];
      };
    };
  };
}
