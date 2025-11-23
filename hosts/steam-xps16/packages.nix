{ pkgs, ... }:
{
  # Minimal system packages for gaming machine
  environment.systemPackages = with pkgs; [
    # Essential utilities
    git
    neovim
    nushell
    curl
    wget
    tree

    # System monitoring
    alsa-utils
    lm_sensors
    sysstat

    # Security
    age
    gnupg

    # Terminal emulator (needed for KDE)
    kitty
  ];
}
