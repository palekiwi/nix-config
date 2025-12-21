{ ... }:

{
  imports =
    [
      ../../modules/cachix.nix
      ../../modules/docker.nix
      ../../modules/server.nix
      ./appdaemon.nix
      ./gotify.nix
      ./hardware-configuration.nix
      ./homeassistant.nix
      ./mosquitto.nix
      # ./nextcloud.nix
      ./postgres.nix
      ./sops.nix
      ./taskchampion.nix
      ./zigbee2mqtt.nix
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

    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [
        3002 # firecrawl
        3003 # firecrawl-mcp
        8088 # nextcloud
      ];
    };

    # networking.firewall.allowedUDPPorts = [ ... ];

    virtualisation.podman.enable = true;

    system.stateVersion = "24.11";
  };
}
