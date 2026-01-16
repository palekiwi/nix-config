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
    # jrnl
    jq
    pandoc
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
