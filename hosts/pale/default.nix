{ pkgs, ... }:

{
  imports =
    [
      ./awesome.nix
      ./hardware-configuration.nix
      ./locale.nix
      ./nvidia.nix
      ./packages.nix
      ./sound.nix
      ./ssh.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix
      ../../modules/docker.nix
    ];

  config = {
    modules.docker.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "pale";

    networking.networkmanager.enable = true;

    system.stateVersion = "24.11";
  };
}
