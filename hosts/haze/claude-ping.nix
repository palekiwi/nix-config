{ pkgs, lib, config, ... }:

let
  namespaces = [ "cast" "cast-sb" ];

  mkService =
    namespace:
    {
      description = "Periodic opencode/cast ping (claude-haiku) - ${namespace}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "pl";
        Group = "users";
        WorkingDirectory = "/home/pl/code/${namespace}";
        # Ensure the per-namespace working directory exists.
        # Runs as User=pl, who owns /home/pl. Leading '-' keeps the unit
        # starting even if mkdir fails (e.g. already present).
        ExecStartPre = "-${pkgs.coreutils}/bin/mkdir -p /home/pl/code/${namespace}";
        Environment = [
          "CAST_VOLUMES_NAMESPACE=${namespace}"
          "CAST_AGENT_VERSIONS__OPENCODE=1.17.11"
        ];
      };

      # `cast` shells out to `docker`, which isn't on a service's default PATH.
      # Reference the configured daemon package so the CLI matches its version.
      path = [
        pkgs.nix
        config.virtualisation.docker.package
      ];

      script = ''
        nix run github:palekiwi-labs/cast#cast -- \
          run opencode run "hi" --model "anthropic/claude-haiku-4-5"
      '';
    };

  mkTimer =
    namespace:
    {
      description = "Daily 6am start, then every 5h5m after completion - ${namespace}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        OnUnitInactiveSec = "5h 5m";
        Persistent = true;
        Unit = "claude-ping-${namespace}.service";
      };
    };
in
{
  systemd.services = builtins.listToAttrs (
    map (n: lib.nameValuePair "claude-ping-${n}" (mkService n)) namespaces
  );

  systemd.timers = builtins.listToAttrs (
    map (n: lib.nameValuePair "claude-ping-${n}" (mkTimer n)) namespaces
  );
}
