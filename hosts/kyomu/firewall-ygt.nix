{ config, lib, ... }:
{
  config = lib.mkIf config.modules.docker.enable {
    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [ 3030 8080 9200 ];
    };
  };
}
