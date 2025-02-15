{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    age
    alsa-utils
    curl
    git
    gitui
    gnupg
    lm_sensors
    neovim
    sysstat
    tree
    wget
  ];
}

