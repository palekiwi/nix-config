{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    acpi
    bat
    cachix
    cmus
    eza
    fasd
    fd
    fzf
    (lib.lowPrio go-task)
    home-assistant-cli
    jrnl
    jq
    neovim
    pandoc
    pass
    ranger
    ripgrep
    starship
    taskwarrior-tui
    taskwarrior3
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
