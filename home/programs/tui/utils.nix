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
    home-assistant-cli
    jq
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
    zoxide
  ];
}
