{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cube-remote;

  cases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (action: command: ''
      ${lib.escapeShellArg action}) ( ${command} ) || echo "cube-remote: $action failed" >&2 ;;'') cfg.actions
  );

  script = pkgs.writeShellApplication {
    name = "cube-remote";
    runtimeInputs = [
      pkgs.mosquitto
      pkgs.jq
      pkgs.xdotool
      pkgs.wireplumber
    ];
    text = ''
      if [ -z "''${DISPLAY:-}" ]; then
        echo "cube-remote: DISPLAY is not set" >&2
        exit 1
      fi

      mosquitto_sub -h ${lib.escapeShellArg cfg.host} -p ${toString cfg.port} \
        -t ${lib.escapeShellArg cfg.topic} \
        | jq --unbuffered -r 'select((.action | type) == "string" and .action != "") | "\(.action) \(.angle // 0)"' \
        | while read -r action angle; do
            echo "cube-remote: $action $angle"
            export ANGLE="$angle"
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
    actions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        shake = "xdotool key Pause";
      };
      description = ''
        Map of cube action to a shell command. The rotation angle in degrees
        is available as $ANGLE (0 for actions without an angle). xdotool and
        wpctl are on PATH.
      '';
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
