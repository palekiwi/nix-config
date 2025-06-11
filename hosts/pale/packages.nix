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
    sysstat
    tree
    wget
    xscreensaver
  ];
}

