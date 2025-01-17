{ pkgs, ... }:

{
  home.packages = with pkgs; [
    arc-icon-theme
    gpick
    libnotify
    maim
    playerctl
    pulseaudio
    signal-desktop
    simplescreenrecorder
    unclutter-xfixes
    wmctrl
    xclip
    xdotool
  ];
}
