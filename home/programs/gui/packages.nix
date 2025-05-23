{ pkgs, ... }:

{
  home.packages = with pkgs; [
    acpi
    bat
    eza
    fasd
    maim
    fzf
    git
    gitui
    gh
    gh-f
    gh-s
    google-chrome
    jq
    lua
    pass
    ranger
    ripgrep
    universal-ctags
    tree
    which
    tldr
    arc-icon-theme
    kdePackages.breeze-gtk
    playerctl
    gnumake
    dmenu
  ];
}
