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
        RPAD = [ "BTN_LEFT" ];
        START = [ "KEY_LEFTMETA" "KEY_ENTER" ];
        BACK = [ "KEY_LEFTMETA" "KEY_BACKSPACE" ];
        LB = [ "KEY_LEFTCTRL" "KEY_PAGEUP" ];
        RB = [ "KEY_LEFTCTRL" "KEY_PAGEDOWN" ];
      };
      pads = {
        left = {
          scrollSpeed = 1.0;
          haptics = 4096;
        };
        right = {
          sensitivity = 3.0;
          haptics = 256;
        };
      };
      menus.tags.items = [
        { label = "r 一"; keys = [ "KEY_LEFTMETA" "KEY_R" ]; }
        { label = "s 二"; keys = [ "KEY_LEFTMETA" "KEY_S" ]; }
        { label = "t 三"; keys = [ "KEY_LEFTMETA" "KEY_T" ]; }
        { label = "f 八"; keys = [ "KEY_LEFTMETA" "KEY_F" ]; }
        { label = "w 七"; keys = [ "KEY_LEFTMETA" "KEY_W" ]; }
        { label = "a 〇"; keys = [ "KEY_LEFTMETA" "KEY_A" ]; }
      ];
      layers.RT = {
        pads.left.menu = "tags";
        buttons.B = [ "KEY_LEFTMETA" "KEY_Q" ];
        dpad = {
          up = [ "KEY_LEFTMETA" "KEY_TAB" ];
          down = [ "KEY_LEFTMETA" "KEY_U" ];
          left = [ "KEY_LEFTMETA" "KEY_N" ];
          right = [ "KEY_LEFTMETA" "KEY_I" ];
        };
      };
    };
  };
}
