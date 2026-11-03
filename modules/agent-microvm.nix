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

  networking.firewall.extraCommands = ''
    ip46tables -w -N agent-vm-in 2>/dev/null || true
    ip46tables -w -F agent-vm-in
    ip46tables -w -A agent-vm-in -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
    ip46tables -w -A agent-vm-in -j DROP
    ip46tables -w -D INPUT -i ${tap} -j agent-vm-in 2>/dev/null || true
    ip46tables -w -I INPUT -i ${tap} -j agent-vm-in
  '';
  networking.firewall.extraStopCommands = ''
    ip46tables -w -D INPUT -i ${tap} -j agent-vm-in 2>/dev/null || true
    ip46tables -w -F agent-vm-in 2>/dev/null || true
    ip46tables -w -X agent-vm-in 2>/dev/null || true
  '';

  networking.hosts.${guestAddr} = [ "agent-vm" ];
}
