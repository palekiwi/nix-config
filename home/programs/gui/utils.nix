{ config, pkgs, ... }:

let
  extra = if config.fedora
          then []
          else with pkgs; [ nextcloud-client ];
in
{
  home.packages = with pkgs; [
    arc-icon-theme
    dmenu
    gpick
    insomnia
    libnotify
    maim
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

  ] ++ extra;
}
