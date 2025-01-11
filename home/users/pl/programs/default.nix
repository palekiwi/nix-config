{ pkgs, config, lib, ... }: {

  imports = [
    ./common.nix
    ./kitty.nix
    ./packages.nix
    ./sesh.nix
    ./starship.nix
    ./ygt.nix
  ];
}
