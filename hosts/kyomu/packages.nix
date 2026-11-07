{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    age
    alsa-utils
    curl
    git
    gitui
    gnupg
    inotify-tools
    lm_sensors
    neovim
    nushell
    sysstat
    tree
    wget
    xscreensaver
    firefox
  ];

  programs.firefox.enable = true;
}