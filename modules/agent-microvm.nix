{ lib, pkgs, ... }:
let
  tap = "vm-agent";
  hostAddr = "10.77.0.1";
  guestAddr = "10.77.0.2";
  ip = lib.getExe' pkgs.iproute2 "ip";
in
{
  microvm.vms.agent = {
    autostart = false;
    config = {
      imports = [ ../vm/agent ];

      microvm.binScripts.tap-up = lib.mkAfter ''
        ${ip} addr replace ${hostAddr}/32 dev ${tap}
        ${ip} route replace ${guestAddr}/32 dev ${tap}
      '';
    };
  };

  networking.networkmanager.unmanaged = [ "interface-name:${tap}" ];

  networking.nat = {
    enable = true;
    internalIPs = [ "${guestAddr}/32" ];
  };

  networking.hosts.${guestAddr} = [ "agent-vm" ];
}
