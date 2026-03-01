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

  services.printing.enable = false;

  environment.shellAliases = {
    gu = "gitui";
    v = "nvim";
    rebuild = "sudo nixos-rebuild switch --flake ~/nix-config#$(hostname -s)";
  };
}
