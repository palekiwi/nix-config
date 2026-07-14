# Project Log

## [3af0a16-dirty] Harden claude-ping: pin cast via flake input (cast-haze)

Replaced the unpinned `nix run github:palekiwi-labs/cast#cast` invocation in hosts/haze/claude-ping.nix with a flake input `cast-haze` pinned to rev 20201aa8c6a919a53d5798c2c36e8f2ab9ede7f9, and made that same package available systemwide on haze.

Changes:
- flake.nix: new `cast-haze` input (rev in URL + inputs.nixpkgs.follows), passed to haze via specialArgs.
- hosts/haze/claude-ping.nix: module formal `cast-haze`; script now `${cast-haze}/bin/cast ...`; removed dead `pkgs.nix` from service `path` (only existed for `nix run`); `pkgs` formal retained (pkgs.coreutils still used in ExecStartPre).
- hosts/haze/default.nix: `environment.systemPackages = [ cast-haze ]` (haze has no pl@haze home-manager config, so cast was not previously available interactively).

Build verification NOT yet run: the sandbox denies `nix`, so `nix flake lock` / `nix build` must run on haze. flake.lock will gain a new cast-haze node on first lock.

- **Found:** home/flake.lock already pins cast to the exact same rev (20201aa8...) via a bare-URL input with no follows
- **Found:** haze has no pl@haze home-manager config (home/flake.nix only covers deck/pale/sayuri/kyomu), so cast was unavailable to the pl user interactively before this change
- **Found:** the old `nix run github:...#cast` resolved master at runtime, so the daily timer could run a different cast than tested, and it required pkgs.nix on the service PATH
- **Found:** cast shells out to host `docker` (not `nix`); pkgs.nix was only needed for `nix run`
- **Found:** repo input-naming convention is hyphenated (home-manager, notifications-server, claude-desktop, nixpkgs-unstable), so cast-haze fits
- **Decided:** Name the input/specialArg/module-formal `cast-haze` (not `cast`) to signal it is haze-scoped; propagated the name end-to-end for a 1:1 mapping. Package output stays `cast` (inputs.cast-haze.packages.x86_64-linux.cast).
- **Decided:** Pin via rev-in-URL (github:palekiwi-labs/cast/<rev>) for transparency and deliberate bumps, rather than bare-URL + lock (which the home flake uses and which drifts on `nix flake update`).
- **Decided:** Add inputs.nixpkgs.follows = nixpkgs to dedupe, matching sibling palekiwi-labs inputs cue/notifications-server in this flake.
- **Decided:** Declare systemwide cast in hosts/haze/default.nix (natural systemwide spot), passing the arg via haze specialArgs (same pattern as z2m).
- **Decided:** Remove pkgs.nix from the service path since nix run is gone; keep config.virtualisation.docker.package.
- **Decided:** Hold the git commit until the haze rebuild is verified green, since the sandbox cannot run nix.
- **Open:** Run `nix flake lock` then `nix build .#nixosConfigurations.haze.config.system.build.toplevel` (or nixos-rebuild build) on haze to confirm evaluation + that the cast-haze node locks at the named rev.
- **Open:** After green rebuild, confirm `cast --version` resolves to the pinned build and `systemctl status claude-ping-cast` still fires.
- **Open:** Consider whether home/flake.nix cast input should also get follows + rev-in-URL for consistency (out of scope here).

## [574e08e] Commit 574e08e: pin cast via cast-haze flake input

Committed 574e08e on branch migrate-haze-redis: "haze/claude-ping: pin cast via flake input". 3 files changed, 15 insertions(+), 5 deletions(-). This commit makes the claude-ping timer and the haze systemwide cast use a single reproducible cast version pinned in flake.nix, instead of the runtime-resolved `nix run github:palekiwi-labs/cast#cast`.

- **Decided:** Committed without running the nix build (sandbox denies nix); user explicitly approved committing with haze-rebuild verification to follow.
- **Decided:** Subject follows repo scope style `haze/claude-ping: <summary>` with an explanatory bulleted body, matching sibling commits like 'haze/claude-ping: put docker on the service PATH'.
- **Open:** On haze: run `nix flake lock` (adds the cast-haze node to flake.lock) then `nixos-rebuild build --flake .#haze` to confirm evaluation. flake.lock itself is NOT part of this commit and will be regenerated on haze.
- **Open:** After green rebuild: verify `cast --version` and `systemctl status claude-ping-cast`.
- **Open:** flake.lock update will be a separate commit on haze once generated.

