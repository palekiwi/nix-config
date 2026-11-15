{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.github-service;
  toml = pkgs.formats.toml { };
  generatedConfig = toml.generate "github.toml" {
    repositories = cfg.repositories;
    poll_seconds = cfg.pollInterval;
    nats_url = cfg.natsUrl;
  };
  home = config.users.users.${cfg.user}.home;
  group = config.users.users.${cfg.user}.group;
in
{
  options.services.github-service = {
    enable = lib.mkEnableOption "the GitHub collection service";
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system}.github-service;
      description = "Package providing the long-running GitHub collector.";
    };
    executable = lib.mkOption {
      type = lib.types.str;
      default = "github-service";
      description = "Executable name in the package's bin directory.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "pl";
      description = "Existing user that owns the private collector state.";
    };
    repositories = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+");
      default = [ ];
      description = "Explicit GitHub repositories to collect.";
    };
    pollInterval = lib.mkOption {
      type = lib.types.ints.between 15 1800;
      default = 120;
      description = "Polling interval in seconds.";
    };
    stateHome = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.local/state";
      description = "XDG state root; the collector appends cue/github.";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${cfg.stateHome}/cue/github";
      description = "Private directory for the collector's SQLite state.";
    };
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.config/cue/github.toml";
      description = "Read-only declaratively generated TOML configuration path.";
    };
    natsUrl = lib.mkOption {
      type = lib.types.str;
      default = "nats://127.0.0.1:4222";
      description = "Local NATS leaf endpoint for collection requests and events.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Explicit proxy, CA and placeholder credential environment.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.palekiwi.machineRole == "vm";
        message = "The GitHub collection service is VM-only.";
      }
      {
        assertion = cfg.repositories != [ ];
        message = "The GitHub collection service needs explicit repositories.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${home}/.config 0700 ${cfg.user} ${group} -"
      "d ${home}/.local 0700 ${cfg.user} ${group} -"
      "d ${cfg.stateHome} 0700 ${cfg.user} ${group} -"
      "d ${cfg.stateHome}/cue 0700 ${cfg.user} ${group} -"
      "d ${builtins.dirOf cfg.configFile} 0700 ${cfg.user} ${group} -"
      "L+ ${cfg.configFile} - - - - ${generatedConfig}"
      "d ${cfg.stateDirectory} 0700 ${cfg.user} ${group} -"
    ];

    systemd.services.github-service = {
      description = "GitHub repository collection service";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "agent-nats-leaf.service"
      ];
      after = [
        "network-online.target"
        "agent-nats-leaf.service"
      ];
      path = [ pkgs.gh ];
      environment = cfg.environment // {
        HOME = home;
        XDG_STATE_HOME = cfg.stateHome;
      };
      restartTriggers = [ generatedConfig ];
      serviceConfig = {
        User = cfg.user;
        Group = group;
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/${cfg.executable}"
          "--config"
          cfg.configFile
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ cfg.stateDirectory ];
      };
    };
  };
}
