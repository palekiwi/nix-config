{ pkgs, ... }:

{
  systemd.services.claude-ping = {
    description = "Periodic opencode/cast ping (claude-haiku)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "pl";
      Group = "users";
      WorkingDirectory = "/home/pl/code/test";
      # Ensure the working directory exists. Runs as User=pl, who owns /home/pl.
      # Leading '-' keeps the unit starting even if mkdir fails.
      ExecStartPre = "-${pkgs.coreutils}/bin/mkdir -p /home/pl/code/test";
      Environment = [
        "CAST_VOLUMES_NAMESPACE=cast"
        "CAST_AGENT_VERSIONS__OPENCODE=1.17.11"
      ];
    };

    path = [ pkgs.nix ];

    script = ''
      ${pkgs.nix}/bin/nix run github:palekiwi-labs/cast/6a8ecd686eef6612d995b680e0a185e0efb101d0#cast -- \
        run opencode run "hi" --model "anthropic/claude-haiku-4-5"
    '';
  };

  systemd.timers.claude-ping = {
    description = "Daily 6am start, then every 5h5m after each run completes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      OnUnitInactiveSec = "5h 5m";
      Persistent = true;
      Unit = "claude-ping.service";
    };
  };
}
