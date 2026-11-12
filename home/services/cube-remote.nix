{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cube-remote;

  cases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (action: key: ''
      ${lib.escapeShellArg action}) xdotool key ${lib.escapeShellArg key} || echo "cube-remote: xdotool failed" >&2 ;;'') cfg.keys
  );

  script = pkgs.writeShellApplication {
    name = "cube-remote";
    runtimeInputs = [
      pkgs.mosquitto
      pkgs.jq
      pkgs.xdotool
    ];
    text = ''
      if [ -z "''${DISPLAY:-}" ]; then
        echo "cube-remote: DISPLAY is not set" >&2
        exit 1
      fi

      mosquitto_sub -h ${lib.escapeShellArg cfg.host} -p ${toString cfg.port} \
        -t ${lib.escapeShellArg cfg.topic} \
        | jq --unbuffered -r '.action | strings | select(. != "")' \
        | while read -r action; do
            echo "cube-remote: $action"
            case "$action" in
              ${cases}
              *) ;;
            esac
          done
    '';
  };
in
{
  options.services.cube-remote = {
    enable = lib.mkEnableOption "Aqara cube as a remote via zigbee2mqtt";
    host = lib.mkOption {
      type = lib.types.str;
      default = "haze";
      description = "MQTT broker host.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 1883;
      description = "MQTT broker port.";
    };
    topic = lib.mkOption {
      type = lib.types.str;
      default = "zigbee2mqtt/Cube";
      description = "zigbee2mqtt topic of the cube.";
    };
    keys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        shake = "Pause";
      };
      description = "Map of cube action to xdotool key name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ script ];

    systemd.user.services.cube-remote = {
      Unit = {
        Description = "Aqara cube remote";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe script;
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
