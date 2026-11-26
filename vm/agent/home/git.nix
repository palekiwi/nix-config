{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  endpoint = import ../../../modules/agent-nats/endpoint.nix;
  natsUrl = "nats://127.0.0.1:${toString endpoint.clientPort}";

  hookNames = [
    "applypatch-msg"
    "pre-applypatch"
    "post-applypatch"
    "pre-commit"
    "pre-merge-commit"
    "prepare-commit-msg"
    "commit-msg"
    "post-commit"
    "pre-rebase"
    "post-checkout"
    "post-merge"
    "pre-push"
    "post-rewrite"
    "pre-auto-gc"
  ];

  dispatch = pkgs.writeShellScript "git-hook-dispatch" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.natscli
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }:$PATH
    export GIT_ACTIVITY_NATS_URL=''${GIT_ACTIVITY_NATS_URL:-${natsUrl}}
    ${builtins.readFile ./git-hooks/dispatch.sh}
  '';

  hooksDir = pkgs.runCommand "git-global-hooks" { } ''
    mkdir -p $out
    ${lib.concatMapStrings (name: ''
      ln -s ${dispatch} $out/${name}
    '') hookNames}
  '';
in
{
  home.packages = [
    inputs.git-pr-sync.packages.${pkgs.stdenv.hostPlatform.system}.git-pr-sync
  ];

  programs.git = {
    enable = true;
    package = null;
    ignores = import ../../../home/programs/tui/gitignores.nix;
    settings = {
      user = {
        name = "Pawel Lisewski";
        email = "dev@palekiwi.com";
      };
      init.defaultBranch = "master";
      pull.rebase = true;
      core.hooksPath = "${hooksDir}";
    };
  };
}
