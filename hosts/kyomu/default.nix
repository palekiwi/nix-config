{ ... }:

{
  imports =
    [
      ./desktop.nix
      ./firewall-docker.nix
      ./firewall-ygt.nix
      ./hardware-configuration.nix
      ./input-method.nix
      ./locale.nix
      ./notifications-server.nix
      ./packages.nix
      ./sound.nix
      ./ssh.nix
      ./system.nix
      ./user.nix

      ../../users/pl/default.nix

      ../../modules/cachix.nix
      ../../modules/docker.nix
      ../../modules/fonts.nix
      ../../modules/sops.nix
      ../../modules/sc-controller-cc
      ../../modules/yubikey.nix
    ];

  config = {
    modules.docker.enable = true;

    systemd.user.services.scc-daemon.unitConfig.ConditionUser = "pl";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "kyomu";
    networking.networkmanager.enable = true;

    system.stateVersion = "25.05";
  };
}
