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
      ../../modules/fonts.nix
      ../../modules/ibus.nix
      ../../modules/sops.nix
      ../../modules/yubikey.nix
    ];

  config = {
    modules.docker.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    boot.initrd.luks.devices = {
      "luks-f9d8ffcf-b76f-4a3e-acad-90a6665d1bfc" = {
        device = "/dev/disk/by-uuid/f9d8ffcf-b76f-4a3e-acad-90a6665d1bfc";
      };
    };

    networking.hostName = "pale";

    networking.networkmanager.enable = true;

    system.stateVersion = "24.11";
  };
}
