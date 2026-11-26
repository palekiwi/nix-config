{ ... }:
{
  imports = [
    ./tmux.nix
    ./cue-platform.nix
  ];

  home.username = "pl";
  home.homeDirectory = "/home/pl";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
