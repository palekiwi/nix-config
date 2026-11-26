{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    pkgs.kitty.terminfo
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];
}
