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

    networking.hostName = "akemi";

    networking.networkmanager.enable = true;

    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.pl.extraGroups = [ "dialout" ];

    services.udev.extraRules = ''
      KERNEL=="ttyUSB0", OWNER="pl"
    '';

    networking.firewall.allowedTCPPorts = [ 8080 8123 5050 ];
    # networking.firewall.allowedUDPPorts = [ ... ];

    virtualisation.podman.enable = true;

    system.stateVersion = "24.11";
  };
}
