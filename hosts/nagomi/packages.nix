{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    age
    alsa-utils
    curl
    git
    gnupg
    lm_sensors
    neovim
    sysstat
    tree
    wget
    firefox
  ];

  programs.firefox.enable = true;
}
