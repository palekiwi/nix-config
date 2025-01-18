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

    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];

    system.stateVersion = "24.11";
  };
}
