{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      gitui
      go-task
      nodejs
      python3
    ]
    ++ import ../../../home/programs/tui/scripts/git-base.nix pkgs;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = false;
  };
}
