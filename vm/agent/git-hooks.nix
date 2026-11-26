{ pkgs, ... }:
let
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  natsUrl = "nats://127.0.0.1:${toString endpoint.clientPort}";

  stream = pkgs.writeText "git-activity-stream.json" (
    builtins.toJSON {
      name = "GIT_ACTIVITY";
      subjects = [ "git.evt.>" ];
      retention = "limits";
      storage = "file";
      max_age = 2592000000000000;
      max_bytes = 268435456;
      duplicate_window = 120000000000;
      discard = "old";
      num_replicas = 1;
    }
  );
in
{
  systemd.services.git-activity-stream = {
    description = "Ensure the GIT_ACTIVITY JetStream stream on the hub";
    wantedBy = [ "multi-user.target" ];
    requires = [ "agent-nats-leaf.service" ];
    after = [ "agent-nats-leaf.service" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
    };
    script =
      let
        nats = "${pkgs.natscli}/bin/nats --server ${natsUrl} --js-domain ${endpoint.jsDomain}";
      in
      ''
        if ${nats} stream info GIT_ACTIVITY >/dev/null 2>&1; then
          ${nats} stream edit GIT_ACTIVITY --config ${stream} --force
        else
          ${nats} stream add GIT_ACTIVITY --config ${stream} --defaults
        fi
      '';
  };
}
