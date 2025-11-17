{ pkgs, ... }:

{
  imports =
    [
      ./firewall-docker.nix
      ./firewall-ygt.nix
      ./hardware-configuration.nix
      ./locale.nix
      ./notifications-server.nix
      ./packages.nix
      ./ssh.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix

      ../../modules/cachix.nix
      ../../modules/docker.nix
      ../../modules/fonts.nix
      ../../modules/sops.nix
      ../../modules/yubikey-headless.nix
    ];

  config = {
    modules.docker.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_6_16;

    networking.hostName = "kyomu";
    networking.networkmanager.enable = true;

    system.stateVersion = "25.05";
  };
}
