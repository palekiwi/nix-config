{ pkgs, config, lib, ... }: {

  imports = [
    ./cmus.nix
    ./gh.nix
    ./git.nix
    ./sesh.nix
    ./starship.nix
    ./tmux.nix
    ./utils.nix
    ./ygt.nix
    ./zsh.nix
  ];
}
