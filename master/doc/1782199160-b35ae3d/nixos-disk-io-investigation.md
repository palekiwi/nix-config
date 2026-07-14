# Investigating disk I/O bottlenecks on NixOS (host: pale)

Point-in-time research. Context: host `pale` reports intermittent full-disk-IO freezes.

## Config facts that matter (host: pale)

- Single ext4 root on LUKS, no separate /nix, /home, /var — `hosts/pale/hardware-configuration.nix:16-27`. Everything shares one device queue.
- Physical swap partition on same device — `hardware-configuration.nix:29-31`.
- Weekly `nix.gc` deleting paths >7d — `hosts/pale/system.nix:5-9`.
- Docker enabled — `modules/docker.nix:12-15` via `hosts/pale/default.nix:33`.
- Ollama with CUDA, `loadModels = []` (models get evicted/re-read) — `hosts/pale/ollama.nix:3-7`.
- No ZFS/btrfs, no restic/borg, no postgres, no auto-optimise-store, no fstrim, no smartd.

## Tools to install

```nix
environment.systemPackages = with pkgs; [ sysstat iotop-c fatrace bcc bpftrace atop ];
```

## Triage recipe (run during a freeze)

```sh
sudo pidstat -d 1      # WHO reads/writes
iostat -x 1            # device %util + await/svctm
mpstat 1               # %iowait
vmstat 1               # swap in/out (si/so) + wa
sudo fatrace -c | head # WHAT files
```

## Disambiguating the symptom

- High `%util` + normal `await` = saturated bandwidth/IOPS (a greedy process).
- High `await`/`svctm` + moderate `%util` = slow/failing disk. Run `smartctl -a`.
- High `wa`/iowait with non-zero `si`/so` = memory-pressure swap thrashing (not a process problem).
- Use `ext4slower 1` (bcc) to print only slow ext4 ops.

## File-level tracing

- `sudo fatrace` — global fs access trace (the killer tool). Filter with grep on O_WRONLY/O_RDWR.
- `sudo biotop` / `sudo biosnoop` / `sudo biolatency` (bcc, block-level).
- `sudo opensnoop -p <pid>` (bcc).

## Scheduled culprits

```sh
systemctl list-timers --all
systemctl status nix-gc.service
journalctl -u nix-gc.service --since today
docker ps && docker stats && docker system df && du -sh /var/lib/docker
```

## Historical

```sh
journalctl --since "1 hour ago" | grep -iE 'oom|killed|gc|docker'
atopsar -d 1            # requires atop-rotate enabled
atop -r /var/log/atop/* # replay; 't' step, 'd' disk view
```

## SMART (no smartd configured)

```sh
sudo smartctl -a /dev/nvme0n1
sudo smartctl -t short /dev/nvme0n1
```

## Suspects ranked for this config

1. Swap thrashing (Ollama model load / Docker pull) — physical swap on same LUKS/ext4 device as everything. Check `vmstat si/so` first.
2. Docker container writing to a volume/log. Check `docker stats`, `/var/lib/docker` size.
3. Weekly nix.gc — correlate freeze day with `systemctl status nix-gc`.
4. Failing disk — no smartd watching; run smartctl.
5. Ollama re-reading evicted models (loadModels = []) — bursty multi-GB reads.

## Open questions for the user

- Symptom onset vs. enabling Docker/Ollama or adding a container?
- Time-of-day clustering (GC timer)?
- Low free RAM during the freeze?
