{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.agentMqtt;
  endpoint = import ../../modules/agent-mqtt/endpoint.nix;
  clients = pkgs.callPackage ../../modules/agent-mqtt/clients { };
in
{
  options.agentMqtt.inboxAgents = lib.mkOption {
    type = lib.types.listOf (lib.types.strMatching "[a-z0-9-]{1,32}");
    default = [ "pi" ];
    description = "Agent names whose host/agent/<name>/inbox messages the inbox listener accepts.";
  };

  config = {
    environment.systemPackages = [ clients.speak ];

    systemd.tmpfiles.rules = [ "d ${endpoint.credentials.guestDir} 0700 pl users -" ];

    systemd.user.services.agent-mqtt-inbox = {
      description = "Agent inbox listener (log only)";
      wantedBy = [ "default.target" ];
      unitConfig = {
        ConditionUser = "pl";
      }
      // clients.unit.unitConfig;
      environment.AGENT_MQTT_AGENTS = lib.concatStringsSep " " cfg.inboxAgents;
      serviceConfig = {
        ExecStart = lib.getExe clients.inboxListener;
      }
      // clients.unit.serviceConfig;
    };
  };
}
