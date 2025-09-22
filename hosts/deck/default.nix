{ pkgs, ... }:

{
  imports =
    [
      ./awesome.nix
      ./bluetooth.nix
      ./firewall-docker.nix
      ./hardware-configuration.nix
      ./locale.nix
      ./notifications-server.nix
      ./packages.nix
      ./picom.nix
      ./sound.nix
      ./ssh.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix

      ../../modules/docker.nix
      ../../modules/fonts.nix
      ../../modules/ibus.nix
      ../../modules/sops.nix
      ../../modules/yubikey.nix
    ];

  config = {
    modules.docker.enable = true;
    modules.ibus.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_6_12;

    networking.hostName = "deck";

    networking.networkmanager.enable = true;

    system.stateVersion = "25.05";
  };
}
