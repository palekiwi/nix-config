{ ... }:
{
  imports = [
    ./tmux.nix
    ./cue-platform.nix
    ./claude-code.nix
    ./dev.nix
    ./shell.nix
    ./nvim.nix
    ./git.nix
    ./github-service.nix
    ./llm-containers.nix
  ];

  home.username = "pl";
  home.homeDirectory = "/home/pl";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
