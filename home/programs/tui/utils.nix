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
