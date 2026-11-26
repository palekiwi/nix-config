{ lib, pkgs, ... }:
let
  docker = lib.getExe' pkgs.docker "docker";
  network = "agent-llm";
  networkUnit = "docker-network-${network}.service";

  containers = {
    "9router" = {
      image = "docker.io/decolua/9router:0.5.119@sha256:38e58865ff111599f409f44430084ad0016c2ba530757ef545848d4bbe0cf007";
      ports = [ "127.0.0.1:20128:20128" ];
      environment = {
        PORT = "20128";
        DATA_DIR = "/app/data";
      };
      volumes = [ "9router-data:/app/data" ];
      after = [ ];
    };
    headroom = {
      image = "ghcr.io/headroomlabs-ai/headroom:0.44.0@sha256:10ef5f71c4cae3a02ca28107dfcf379aa73314ff26544c1f9988140e71f732f4";
      ports = [ "127.0.0.1:8787:8787" ];
      environment = {
        HEADROOM_HOST = "0.0.0.0";
        HEADROOM_PORT = "8787";
        HEADROOM_MODE = "cache";
        HEADROOM_BEACON = "off";
        HEADROOM_TELEMETRY = "off";
        HEADROOM_ALLOW_UNAUTHENTICATED_BIND = "1";
        ANTHROPIC_TARGET_API_URL = "http://9router:20128";
        OPENAI_TARGET_API_URL = "http://9router:20128/v1";
      };
      volumes = [ ];
      after = [ "docker-9router.service" ];
    };
  };

  mkService = name: c: {
    Unit = {
      Description = "${name} container";
      Requires = [ networkUnit ];
      After = [ networkUnit ] ++ c.after;
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStartPre = "-${docker} rm -f ${name}";
      ExecStart = lib.escapeShellArgs (
        [
          docker
          "run"
          "--name=${name}"
          "--rm"
          "--pull=missing"
          "--network=${network}"
        ]
        ++ map (p: "--publish=${p}") c.ports
        ++ lib.mapAttrsToList (k: v: "--env=${k}=${v}") c.environment
        ++ map (v: "--volume=${v}") c.volumes
        ++ [ c.image ]
      );
      ExecStop = "${docker} stop ${name}";
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStartSec = "infinity";
    };
  };
in
{
  systemd.user.services = lib.mapAttrs' (
    name: c: lib.nameValuePair "docker-${name}" (mkService name c)
  ) containers
  // {
    "docker-network-${network}" = {
      Unit.Description = "Docker network for agent LLM containers";
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "docker-network-${network}" ''
          ${docker} network inspect ${network} >/dev/null 2>&1 \
            || ${docker} network create ${network}
        '';
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
