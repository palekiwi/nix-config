{ pkgs, lib, ... }:

let
  sc-controller-cc = pkgs.callPackage ./package.nix { };
in
{
  environment.systemPackages = [ sc-controller-cc ];

  hardware.steam-hardware.enable = true;
  hardware.uinput.enable = true;

  systemd.user.services.scc-daemon = {
    description = "SC Controller daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    environment.PATH = lib.mkForce "/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
    serviceConfig = {
      ExecStart = "${lib.getExe' sc-controller-cc "scc-daemon"} start --foreground";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
