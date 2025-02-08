{ ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/docker.nix
      ../../modules/server.nix
    ];

  config = {
    modules.docker.enable = false;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "haze";

    networking.networkmanager.enable = true;

    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.pl = {
      extraGroups = [ "dialout" ];
      linger = true;
    };


   environment.shellAliases = {
     gu = "gitui";
     p = "podman";
     v = "nvim";
   };

    services.udev.extraRules = ''
      KERNEL=="ttyUSB0", OWNER="pl"
    '';

    networking.firewall.allowedTCPPorts = [ 8080 8123 5050 8088 ];
    # networking.firewall.allowedUDPPorts = [ ... ];

    virtualisation.podman.enable = true;

    system.stateVersion = "24.11";
  };
}
