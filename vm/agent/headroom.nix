{ lib, pkgs, ... }:
{
  systemd.services.docker-network-agent = {
    enable = true;
    description = "Docker network for agent LLM containers";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [
      "docker-9router.service"
      "docker-headroom.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${lib.getExe' pkgs.docker "docker"} network create agent-llm"
      ];
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.headroom = {
      image = "ghcr.io/headroomlabs-ai/headroom:0.44.0@sha256:10ef5f71c4cae3a02ca28107dfcf379aa73314ff26544c1f9988140e71f732f4";
      autoStart = true;
      pull = "missing";
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
      extraOptions = [ "--network=agent-llm" ];
    };
  };
}
