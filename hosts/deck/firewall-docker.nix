{ config, lib, ... }:
{
  config = lib.mkIf config.modules.docker.enable {
    networking.firewall.interfaces."docker0" = {
      allowedTCPPorts = [ 33222 ];

      allowedTCPPortRanges = [
       { from = 30300; to = 30309; }
     ];
    };
  };
}
