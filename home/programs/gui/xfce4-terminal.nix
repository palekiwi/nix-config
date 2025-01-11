{ pkgs, ... }:

{
  home.packages = with pkgs; [
    xfce.xfce4-terminal
  ];
}
