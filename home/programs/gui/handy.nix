{ config, lib, pkgs, ... }:

let
  cfg = config.services.handy;
in {
  options.services.handy = {
    enable = lib.mkEnableOption "Handy - Speech to Text service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.handy;
      description = "The Handy package to use.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--start-hidden" ];
      description = "Extra command line arguments for Handy.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Desktop entry for application launchers
    xdg.desktopEntries.handy = {
      name = "Handy";
      exec = "${lib.getExe cfg.package}";
      icon = "accessories-text-editor";
      categories = [ "Utility" "Accessibility" ];
      type = "Application";
      terminal = false;
      comment = "Free, open source speech-to-text application";
    };

    # Systemd user service
    systemd.user.services.handy = {
      Unit = {
        Description = "Handy - Speech to Text";
        # Ensure it starts after the graphical session is ready
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} ${lib.escapeShellArgs cfg.extraArgs}";
        Restart = "on-failure";
        RestartSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
        # Essential for Tauri apps to connect to the display server
        # Include xdotool and other tools in PATH for clipboard pasting
        Environment = [
          "WEBKIT_DISABLE_DMABUF_RENDERER=1"
          "PATH=${lib.makeBinPath [ pkgs.xdotool pkgs.xclip pkgs.wl-clipboard ]}/bin:/run/current-system/sw/bin:/home/pl/.nix-profile/bin"
        ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
