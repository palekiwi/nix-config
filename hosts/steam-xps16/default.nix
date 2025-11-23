{ pkgs, ... }:

{
  imports =
    [
      ./bluetooth.nix
      ./hardware-configuration.nix
      ./kde-plasma.nix
      ./locale.nix
      ./nvidia.nix
      ./packages.nix
      ./sound.nix
      ./ssh.nix
      ./steam.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix

      ../../modules/cachix.nix
      ../../modules/fonts.nix
      ../../modules/sops.nix
      ../../modules/yubikey.nix
    ];

  config = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_6_12;

    networking.hostName = "steam-xps16";

    networking.networkmanager.enable = true;

    system.stateVersion = "25.05";
  };
}
