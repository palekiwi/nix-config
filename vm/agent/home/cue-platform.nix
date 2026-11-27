{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  cp = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system};
  runEnvironment = (pkgs.formats.keyValue { }).generate "cue-supervisor-environment" {
    EDITOR = config.home.sessionVariables.EDITOR;
    DISABLE_AUTOUPDATER = config.home.sessionVariables.DISABLE_AUTOUPDATER;
  };
in
{
  home.packages = [
    cp.pi
    cp.cue
    cp.cue-agent
    cp.cue-recall
    cp.cue-review
    cp.station
    cp.cue-supervisor
    cp.gh
    cp.jq
  ];

  systemd.user.services.cue-supervisor = {
    Unit.Description = "Cue run supervisor";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${cp.cue-supervisor}/bin/cue-supervisor daemon";
      EnvironmentFile = [
        "/etc/agent-vm/environment"
        runEnvironment
      ];
      Environment = [
        "CUE_STORE=/home/pl/cue"
        "CUE_SUPERVISOR_STATE=/home/pl/.local/state/cue-supervisor"
        "\"NIX_PROFILES=/nix/var/nix/profiles/default /run/current-system/sw\""
        "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/pl"
        "PATH=/home/pl/.nix-profile/bin:/run/wrappers/bin:/run/current-system/sw/bin:${
          pkgs.lib.makeBinPath [
            pkgs.bash
            pkgs.bun
            pkgs.coreutils
            pkgs.curl
            pkgs.git
            pkgs.nix
            pkgs.nodejs
            pkgs.systemd
          ]
        }"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };
}
