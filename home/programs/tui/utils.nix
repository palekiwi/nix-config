{ pkgs, ... }:

{
  home.packages = with pkgs; [
    acpi
    bat
    cmus
    eza
    fasd
    fd
    fzf
    graph-easy
    home-assistant-cli
    jq
    neovim
    pass
    ranger
    ripgrep
    slides
    starship
    tldr
    tree
    typescript
    universal-ctags
    unzip
    which
    yubikey-manager
    zoxide
  ];
}
