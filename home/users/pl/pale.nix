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

    services.cube-remote = {
      enable = true;
      actions = {
        shake = "xdotool key Pause";
        tap = "xdotool key Return";
        slide = "xdotool key ctrl+y && sleep 0.3 && xdotool key ctrl+Pause";
        rotate_right = ''wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$(( (''${ANGLE%.*} + 4) / 5 ))%+"'';
        rotate_left = ''wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(( (-''${ANGLE%.*} + 4) / 5 ))%-"'';
      };
    };

    programs.sc-controller.enable = true;
    programs.local-tts = {
      enable = true;
      backend = "http";
      volume = 1.5;
    };
  };
}
