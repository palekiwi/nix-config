{ pkgs, ... }:

{
  imports =
    [
      ./firewall-docker.nix
      ./hardware-configuration.nix
      ./locale.nix
      ./packages.nix
      ./ssh.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix

      ../../modules/docker.nix
      ../../modules/fonts.nix
      ../../modules/sops.nix
    ];

  config = {
    modules.docker.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_6_15;

    networking.hostName = "kyomu";
    networking.networkmanager.enable = true;

    system.stateVersion = "25.05";
  };
}
