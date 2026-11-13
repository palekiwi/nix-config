{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.agent-mqtt;
  endpoint = import ../../modules/agent-mqtt/endpoint.nix;
  clients = pkgs.callPackage ../../modules/agent-mqtt/clients { };
in
{
  options.services.agent-mqtt = {
    enable = lib.mkEnableOption "agent VM MQTT speech request consumer and inbox sender";
    speechPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = endpoint.credentials.hostPasswordFile "host-speech";
      description = "File holding the host-speech MQTT password.";
    };
    inboxPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = endpoint.credentials.hostPasswordFile "host-inbox";
      description = "File holding the host-inbox MQTT password, used by agent-mqtt-inbox-send.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "agent-mqtt-inbox-send" ''
        export AGENT_MQTT_PASSWORD_FILE=${lib.escapeShellArg cfg.inboxPasswordFile}
        exec ${clients.inboxSend}/bin/agent-mqtt-inbox-send "$@"
      '')
    ];

    systemd.user.services.agent-mqtt-speech = {
      Unit = {
        Description = "Agent VM speech request consumer (log only)";
      }
      // clients.unit.unitConfig;
      Service = {
        ExecStart = lib.getExe clients.speechConsumer;
        Environment = [ "AGENT_MQTT_PASSWORD_FILE=${cfg.speechPasswordFile}" ];
      }
      // clients.unit.serviceConfig;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
