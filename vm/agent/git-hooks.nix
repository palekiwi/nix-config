{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  natsUrl = "nats://127.0.0.1:${toString endpoint.clientPort}";

  ignores = pkgs.writeText "gitignore-global" (
    builtins.concatStringsSep "\n" (import ../../home/programs/tui/gitignores.nix) + "\n"
  );

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

  stream = pkgs.writeText "git-activity-stream.json" (
    builtins.toJSON {
      name = "GIT_ACTIVITY";
      subjects = [ "git.evt.>" ];
      retention = "limits";
      storage = "file";
      max_age = 2592000000000000;
      max_bytes = 268435456;
      duplicate_window = 120000000000;
      discard = "old";
      num_replicas = 1;
    }
  );
in
{
  environment.systemPackages = [
    inputs.git-pr-sync.packages.${pkgs.stdenv.hostPlatform.system}.git-pr-sync
  ];

  programs.git.config.core.hooksPath = "${hooksDir}";
  programs.git.config.core.excludesFile = "${ignores}";

  systemd.services.git-activity-stream = {
    description = "Ensure the GIT_ACTIVITY JetStream stream on the hub";
    wantedBy = [ "multi-user.target" ];
    requires = [ "agent-nats-leaf.service" ];
    after = [ "agent-nats-leaf.service" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
    };
    script =
      let
        nats = "${pkgs.natscli}/bin/nats --server ${natsUrl} --js-domain ${endpoint.jsDomain}";
      in
      ''
        if ${nats} stream info GIT_ACTIVITY >/dev/null 2>&1; then
          ${nats} stream edit GIT_ACTIVITY --config ${stream} --force
        else
          ${nats} stream add GIT_ACTIVITY --config ${stream} --defaults
        fi
      '';
  };
}
