{ pkgs, ... }:

{
  home.packages = with pkgs; [
    acpi
    bat
    cmus
    dmenu
    eza
    fasd
    fzf
    home-assistant-cli
    jq
    maim
    neovim
    pass
    pinentry-gtk2
    ranger
    ripgrep
    starship
    tldr
    tree
    typescript
    universal-ctags
    unzip
    which
    yubikey-manager
    zellij
    zoxide
  ];
}
