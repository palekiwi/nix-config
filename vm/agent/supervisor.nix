{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cp = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  systemd.user.services.cue-supervisor = {
    description = "Cue run supervisor";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = "pl";
    path = [
      cp.pi
      cp.cue
      cp.cue-agent
      cp.cue-recall
      cp.cue-review
      cp.cue-supervisor
      cp.gh
      cp.jq
      pkgs.bash
      pkgs.bun
      pkgs.coreutils
      pkgs.curl
      pkgs.git
      pkgs.nix
      pkgs.nodejs
      pkgs.systemd
    ];
    environment = config.environment.variables // {
      CUE_STORE = "/home/pl/cue";
      CUE_SUPERVISOR_STATE = "/home/pl/.local/state/cue-supervisor";
      CUE_NATS_URL = "nats://127.0.0.1:4222";
      CUE_NATS_JS_DOMAIN = "pale";
      NIX_PATH = lib.concatStringsSep ":" config.nix.nixPath;
      NIX_PROFILES = "/nix/var/nix/profiles/default /run/current-system/sw";
      NIX_USER_PROFILE_DIR = "/nix/var/nix/profiles/per-user/pl";
      NIX_SSL_CERT_FILE = config.security.pki.caBundle;
      SSL_CERT_FILE = config.security.pki.caBundle;
    };
    serviceConfig = {
      ExecStart = "${cp.cue-supervisor}/bin/cue-supervisor daemon";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    };
  };
}
