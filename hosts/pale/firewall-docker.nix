{ config, lib, ... }:
{
  config = lib.mkIf config.modules.docker.enable {
    networking.firewall.trustedInterfaces = [ "docker0" ];
  };
}
