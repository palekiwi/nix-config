{ config, lib, ... }:
{
  config = lib.mkIf config.modules.docker.enable {
    networking.firewall.interfaces."docker0" = {
      allowedTCPPorts = [ 30301 ];
    };
  };
}
