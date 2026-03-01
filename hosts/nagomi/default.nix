{ pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./locale.nix
      ./packages.nix
      ./ssh.nix
      ./system.nix
      ./user.nix
      ./desktop.nix
      ./sound.nix

      ../../users/pl/default.nix

      ../../modules/cachix.nix
      ../../modules/fonts.nix
      ../../modules/sops.nix
    ];

  networking.hostName = "nagomi";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
}
