{ pkgs, config, lib, ... }:

let
  extra = if config.fedora
          then []
          else with pkgs; [ ollama-cuda oterm ];
in
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
    (import ./bin/hass.nix { inherit pkgs config; })
    (import ./bin/dmenu_hass.nix { inherit pkgs lib config; })
  ] ++ extra;
}
