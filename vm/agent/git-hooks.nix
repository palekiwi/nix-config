{ pkgs, inputs, ... }:
let
  templates = ../../home/config/git/templates;
in
{
  environment.systemPackages = [
    inputs.git-pr-sync.packages.${pkgs.stdenv.hostPlatform.system}.git-pr-sync
    (import ../../home/programs/tui/scripts/git_hooks_sync.nix { inherit pkgs; })
  ];

  environment.variables.GIT_HOOKS_TEMPLATES = "${templates}";

  programs.git.config.init.templateDir = "${templates}";
}
