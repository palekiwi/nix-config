{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  tap = "vm-agent";
  hostAddr = "10.77.0.1";
  guestAddr = "10.77.0.2";
  ip = lib.getExe' pkgs.iproute2 "ip";
in
{
  imports = [ ./agent-vm-network.nix ];

  microvm.vms.agent = {
    autostart = true;
    restartIfChanged = false;
    specialArgs = { inherit inputs; };
    config = {
      imports = [ ../vm/agent ];

      microvm.binScripts.tap-up = lib.mkAfter ''
        ${ip} addr replace ${hostAddr}/32 dev ${tap}
        ${ip} route replace ${guestAddr}/32 dev ${tap}
      '';
    };
  };
}
