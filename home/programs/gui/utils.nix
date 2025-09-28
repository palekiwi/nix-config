{ pkgs, ... }:

{
  home.packages = with pkgs; [
    arc-icon-theme
    dmenu
    gpick
    insomnia
    libnotify
    maim
    playerctl
    pulseaudio
    signal-desktop
    simplescreenrecorder
    unclutter-xfixes
    vlc
    wmctrl
    xclip
    xdotool
  ];
}
