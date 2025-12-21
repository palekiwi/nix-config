{ config, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";

    containers.appdaemon = {
      image = "docker.io/acockburn/appdaemon:latest";

      ports = [ ];

      volumes = [
        "/srv/ha/appdaemon/conf:/conf"
        "/etc/localtime:/etc/localtime:ro"
      ];

      environment = {
        DASH_URL = "http://localhost:5050";
        HA_URL = "http://localhost:8123";
        TZ = "Asia/Taipei";
      };

      environmentFiles = [
        config.sops.secrets."appdaemon".path
      ];

      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.services."podman-appdaemon" = {
    after = [ "home-assistant.service" ];
    wants = [ "home-assistant.service" ];
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      5050
    ];
  };
}
