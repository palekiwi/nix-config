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

  # Disable printing (not needed for gaming)
  services.printing.enable = false;
}
