{ lib, pkgs, ... }:
let
  tap = "vm-agent";
  hostAddr = "10.77.0.1";
  guestAddr = "10.77.0.2";
  ip = lib.getExe' pkgs.iproute2 "ip";
in
{
  microvm.vms.agent = {
    config = {
      imports = [ ../vm/agent ];

      microvm.binScripts.tap-up = lib.mkAfter ''
        ${ip} addr add ${hostAddr}/32 dev ${tap}
        ${ip} route add ${guestAddr}/32 dev ${tap}
      '';
    };
  };

  microvm.autostart = [ ];

  networking.networkmanager.unmanaged = [ "interface-name:${tap}" ];

  networking.nat = {
    enable = true;
    internalInterfaces = [ tap ];
  };

  networking.firewall.extraCommands = ''
    iptables -I FORWARD -i ${tap} -j ACCEPT
    iptables -I FORWARD -o ${tap} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D FORWARD -i ${tap} -j ACCEPT || true
    iptables -D FORWARD -o ${tap} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
  '';

  networking.hosts.${guestAddr} = [ "agent-vm" ];
}
