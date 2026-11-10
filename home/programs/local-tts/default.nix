{
  config,
  lib,
  pkgs,
  ...
}:
let
  speech = pkgs.callPackage ./package.nix { inherit (config.programs.local-tts) backend; };
  toggle = pkgs.writeShellScriptBin "clipboard-speech-toggle" ''
    exec ${pkgs.python3}/bin/python3 ${./clipboard_toggle.py} ${pkgs.systemd}/bin/systemctl
  '';
in
{
  options.programs.local-tts = {
    enable = lib.mkEnableOption "foreground local text-to-speech";
    backend = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "http"
      ];
      default = "cpu";
      description = "Default speech backend; failures never select another backend.";
    };
  };
  config = lib.mkIf config.programs.local-tts.enable {
    home.packages = [
      speech
      toggle
    ];
    systemd.user.services.clipboard-speech = {
      Unit = {
        Description = "Clipboard speech owned by the desktop toggle";
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "exec";
        ExecStart = "${speech}/bin/speak --clipboard";
        KillMode = "control-group";
        TimeoutStopSec = "2s";
        Restart = "no";
        SuccessExitStatus = [ 130 ];
      };
    };
  };
}
