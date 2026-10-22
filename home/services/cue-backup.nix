{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cue-backup;

  backup-script = pkgs.writeShellScript "cue-backup" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.rsync
        pkgs.coreutils
      ]
    }:$PATH

    set -euo pipefail

    store="${cfg.store}"
    target="${cfg.target}"

    # Hosts without a store stay quiet; the timer stays green.
    if [ ! -d "$store" ]; then
      echo "cue-backup: store $store does not exist on this host; skipping"
      exit 0
    fi

    mkdir -p "$target"

    # Newest existing snapshot; names sort chronologically.
    latest=""
    for d in "$target"/snapshot-*; do
      [ -d "$d" ] || continue
      if [ -z "$latest" ] || [[ "$d" > "$latest" ]]; then
        latest="$d"
      fi
    done

    name="snapshot-$(date +%Y-%m-%dT%H:%M:%S)"
    args=(--archive --delete --info=stats1)
    if [ -n "$latest" ]; then
      args+=(--link-dest="$latest")
    fi
    staging=$(mktemp -d "$target/.incomplete-XXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    rsync "''${args[@]}" "$store"/ "$staging/"
    # -T prevents nesting into an existing destination; -n refuses replacement.
    mv -Tn -- "$staging" "$target/$name"
    if [ -d "$staging" ]; then
      echo "cue-backup: snapshot already exists: $name" >&2
      exit 1
    fi
    echo "cue-backup: created $name"

    # Tiered prune: keep every snapshot from the last 24h, the newest per
    # calendar day for 14 days, then the newest per ISO week for 8 weeks.
    # Hardlinks make kept snapshots cost little beyond directory entries.
    now=$(date +%s)
    snapshots=()
    for d in "$target"/snapshot-*; do
      [ -d "$d" ] || continue
      snapshots+=("$d")
    done

    # Glob order is chronological, so the last write per key is the newest.
    declare -A newest_by_day=() newest_by_week=()
    for d in "''${snapshots[@]}"; do
      ts="''${d##*/snapshot-}"
      epoch=$(date -d "$ts" +%s 2>/dev/null) || continue
      newest_by_day[$(date -d "@$epoch" +%F)]="$d"
      newest_by_week[$(date -d "@$epoch" +%G-W%V)]="$d"
    done

    pruned=0
    for d in "''${snapshots[@]}"; do
      ts="''${d##*/snapshot-}"
      epoch=$(date -d "$ts" +%s 2>/dev/null) || continue
      age=$(( now - epoch ))
      if [ "$age" -lt 86400 ]; then
        continue
      fi
      day=$(date -d "@$epoch" +%F)
      week=$(date -d "@$epoch" +%G-W%V)
      if [ "$age" -lt $((14 * 86400)) ] && [ "$d" = "''${newest_by_day[$day]}" ]; then
        continue
      fi
      if [ "$age" -lt $((8 * 7 * 86400)) ] && [ "$d" = "''${newest_by_week[$week]}" ]; then
        continue
      fi
      rm -rf -- "$d"
      pruned=$(( pruned + 1 ))
    done
    echo "cue-backup: pruned $pruned snapshot(s)"
  '';
in
{
  options.services.cue-backup = {
    enable = lib.mkEnableOption "periodic hardlinked rsync snapshots of the cue store";

    store = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/cue";
      description = "Path of the cue store to back up.";
    };

    target = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/.local/state/cue-backup";
      description = ''
        Directory that receives snapshot-* directories. Must stay outside
        every path mounted into agent sandboxes: the store is writable by
        agents, and an unmounted target is what isolates backups from
        agent corruption or deletion.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      example = "daily";
      description = "OnCalendar expression controlling how often snapshots run.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.cue-backup = {
      Unit.Description = "cue store backup (hardlinked rsync snapshots)";

      Service = {
        Type = "oneshot";
        ExecStart = "${backup-script}";
        Nice = 19;
        IOSchedulingClass = "idle";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.cue-backup = {
      Unit.Description = "Run the cue store backup";

      Timer = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };

      Install.WantedBy = [ "timers.target" ];
    };
  };
}
