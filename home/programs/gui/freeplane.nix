{ pkgs, ... }:

{
  home.packages = with pkgs; [
    freeplane
  ];
}
