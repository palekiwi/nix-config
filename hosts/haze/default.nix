{ ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./gotify.nix
      ../../modules/docker.nix
      ../../modules/server.nix
    ];

  config = {
    modules.docker.enable = true;

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
      rebuild = "sudo nixos-rebuild switch --flake ~/nix-config#$(hostname -f)";
    };

    services.udev.extraRules = ''
      KERNEL=="ttyUSB0", OWNER="pl"
    '';

    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [
        3009 # firecrawl
        3003 # firecrawl-mcp
        5050 # app-daemon
        8080 # zigbee
        8088 # nextcloud
        8123 # home-assistant
      ];
    };

    # networking.firewall.allowedUDPPorts = [ ... ];

    virtualisation.podman.enable = true;

    system.stateVersion = "24.11";
  };
}
