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

  config = {
    modules.sops.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "nagomi";
    networking.networkmanager.enable = true;

    system.stateVersion = "25.11";
  };
}
