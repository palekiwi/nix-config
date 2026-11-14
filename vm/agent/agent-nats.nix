{ lib, pkgs, ... }:
let
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  inherit (endpoint) seed;

  conf = pkgs.writeText "agent-nats-leaf.conf" ''
    server_name: agent-leaf
    host: 127.0.0.1
    port: ${toString endpoint.clientPort}
    max_payload: 65536
    leafnodes {
      reconnect: "2s"
      remotes: [
        {
          url: "nats-leaf://${endpoint.host}:${toString endpoint.leafPort}"
          nkey: ${"$"}${seed.var}
        }
      ]
    }
  '';

  validated =
    pkgs.runCommand "agent-nats-leaf.conf"
      {
        nativeBuildInputs = [
          pkgs.nats-server
          pkgs.nkeys
        ];
      }
      ''
        export ${seed.var}=$(nk -gen user)
        nats-server -c ${conf} -t
        ln -s ${conf} $out
      '';

  checkSeed = pkgs.writeShellScript "agent-nats-leaf-check-seed" ''
    if [ -z "''${${seed.var}:-}" ]; then
      echo "agent-nats-leaf: ${seed.var} not set; ${seed.file} is missing or incomplete." >&2
      echo "agent-nats-leaf: run 'task agent-nats-leaf-seed' in the agent VM, then restart agent-nats-leaf." >&2
      exit 1
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.natscli ];

  systemd.tmpfiles.rules = [ "d ${seed.dir} 0700 root root -" ];

  systemd.services.agent-nats-leaf = {
    description = "NATS leaf node for the agent VM";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      EnvironmentFile = "-${seed.file}";
      ExecStartPre = checkSeed;
      ExecStart = "${lib.getExe' pkgs.nats-server "nats-server"} -c ${validated}";
      ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = "30s";
      DynamicUser = true;
      MemoryMax = "256M";
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      UMask = "0077";
    };
  };
}
