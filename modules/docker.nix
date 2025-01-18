{ config, lib, ... }:
{
  options.modules.docker = {
    enable = lib.mkEnableOption "enable docker";
  };

  config = lib.mkIf config.modules.docker.enable {
    users.users.pl = {
      extraGroups = [ "docker" ];
    };

    virtualisation.docker.enable = true;
  };
}
