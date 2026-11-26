{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  endpoint = import ../../../modules/agent-nats/endpoint.nix;
  package = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system}.cue-github;
  stateHome = config.xdg.stateHome;
  stateDirectory = "${stateHome}/cue/github";
  configFile = "${config.xdg.configHome}/cue/github.toml";
  caBundle = "/etc/ssl/certs/ca-certificates.crt";

  generatedConfig = (pkgs.formats.toml { }).generate "github.toml" {
    repositories = [ "spabreaks/spabreaks" ];
    poll_seconds = 120;
    nats_url = "nats://127.0.0.1:${toString endpoint.clientPort}";
  };

  environment = import ../proxy-env.nix // {
    GH_TOKEN = "PLACEHOLDER-gh-spabreaks";
    GH_PROMPT_DISABLED = "1";
    SSL_CERT_FILE = caBundle;
    NIX_SSL_CERT_FILE = caBundle;
    XDG_STATE_HOME = stateHome;
    PATH = lib.makeBinPath [
      pkgs.gh
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
    ];
  };
in
{
  xdg.configFile."cue/github.toml".source = generatedConfig;

  home.activation.githubServiceStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -d -m 0700 "${stateHome}/cue" "${stateDirectory}"
  '';

  systemd.user.services.github-service = {
    Unit = {
      Description = "GitHub repository collection service";
      X-Restart-Triggers = [ generatedConfig ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${package}/bin/cue-github"
        "--config"
        configFile
      ];
      Environment = lib.mapAttrsToList (name: value: lib.escapeShellArg "${name}=${value}") environment;
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ stateDirectory ];
    };
  };
}
