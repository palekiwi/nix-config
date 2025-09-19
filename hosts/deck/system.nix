{ lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.dconf.enable = true;

  services.gnome.gnome-keyring.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = false;

  services.xscreensaver = {
    enable = true;
  };
}