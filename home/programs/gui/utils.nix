{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    alsa-utils
    arc-icon-theme
    gpick
    libnotify
    maim
    pinentry-gtk2
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
