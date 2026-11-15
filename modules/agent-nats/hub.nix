{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agent-nats;
  endpoint = import ./endpoint.nix;
  inherit (endpoint.accounts) agent host;
  guard = import ../agent-port-guard.nix {
    name = "agent-nats-guard";
    port = endpoint.leafPort;
    inherit (endpoint) tap;
    guestAddr = endpoint.guest;
    listenAddr = endpoint.host;
  };
in
{
  options.services.agent-nats.leafPublicKey = lib.mkOption {
    type = lib.types.nullOr (lib.types.strMatching "U[A-Z2-7]{55}");
    default = null;
    description = ''
      Public user nkey of the agent VM leaf node. While null the hub runs
      without a leafnode listener.
    '';
  };

  config = {
    services.nats = {
      enable = true;
      serverName = "pale";
      port = endpoint.clientPort;
      jetstream = true;
      settings = {
        host = "127.0.0.1";
        max_payload = 65536;
        max_connections = 64;
        jetstream = {
          domain = endpoint.jsDomain;
          max_memory_store = 67108864;
          max_file_store = 1073741824;
        };
        accounts = {
          ${agent} = {
            jetstream = "enabled";
            exports = [
              { stream = endpoint.subjects; }
              { stream = "speech.intent.>"; }
              {
                service = "github.api.v1.*";
                response_type = "singleton";
              }
              { stream = "github.evt.v1.*"; }
            ];
          };
          ${host} = {
            jetstream = "enabled";
            users = [ { user = endpoint.hostUser; } ];
            imports = [
              {
                stream = {
                  account = agent;
                  subject = endpoint.subjects;
                };
              }
              {
                stream = {
                  account = agent;
                  subject = "speech.intent.>";
                };
              }
              {
                service = {
                  account = agent;
                  subject = "github.api.v1.*";
                };
              }
              {
                stream = {
                  account = agent;
                  subject = "github.evt.v1.*";
                };
              }
            ];
          };
        };
        no_auth_user = endpoint.hostUser;
      }
      // lib.optionalAttrs (cfg.leafPublicKey != null) {
        leafnodes = {
          host = "0.0.0.0";
          port = endpoint.leafPort;
          advertise = "${endpoint.host}:${toString endpoint.leafPort}";
          authorization = {
            nkey = cfg.leafPublicKey;
            account = agent;
          };
        };
      };
    };

    systemd.services.nats = {
      after = [ "firewall.service" ];
      wants = [ "firewall.service" ];
      serviceConfig = {
        IPAddressAllow = [
          "${endpoint.guest}/32"
          "127.0.0.0/8"
        ];
        IPAddressDeny = "any";
        MemoryMax = "512M";
        RestrictAddressFamilies = lib.mkForce [ "AF_INET" ];
      };
    };

    systemd.services.nats-control-stream = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "nats.service" ];
      after = [ "nats.service" ];
      partOf = [ "nats.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 2;
      };
      script =
        let
          nats = "${pkgs.natscli}/bin/nats --server nats://127.0.0.1:${toString endpoint.clientPort}";
          stream = pkgs.writeText "control-stream.json" (
            builtins.toJSON {
              name = "CONTROL";
              subjects = [
                "speech.>"
                "dictation.>"
                "cube.>"
              ];
              no_ack = true;
              retention = "limits";
              storage = "file";
              max_age = 604800000000000;
              max_bytes = 67108864;
              discard = "old";
              num_replicas = 1;
            }
          );
        in
        ''
          if ${nats} stream info CONTROL >/dev/null 2>&1; then
            ${nats} stream edit CONTROL --config ${stream} --force
          else
            ${nats} stream add CONTROL --config ${stream} --defaults
          fi
        '';
    };

    environment.systemPackages = [ pkgs.natscli ];

    networking.firewall.extraCommands = lib.mkAfter guard.start;
    networking.firewall.extraStopCommands = guard.stop;
  };
}
