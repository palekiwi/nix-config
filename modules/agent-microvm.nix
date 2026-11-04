{ lib, pkgs, inputs, ... }:
let
  tap = "vm-agent";
  hostAddr = "10.77.0.1";
  guestAddr = "10.77.0.2";
  ip = lib.getExe' pkgs.iproute2 "ip";
  blockedNets = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];
in
{
  microvm.vms.agent = {
    autostart = true;
    specialArgs = { inherit inputs; };
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

    iptables -w -t mangle -N agent-vm-fwd 2>/dev/null || true
    iptables -w -t mangle -F agent-vm-fwd
    ${lib.concatMapStrings (net: ''
      iptables -w -t mangle -A agent-vm-fwd -d ${net} -j DROP
    '') blockedNets}
    iptables -w -t mangle -D FORWARD -i ${tap} -j agent-vm-fwd 2>/dev/null || true
    iptables -w -t mangle -I FORWARD -i ${tap} -j agent-vm-fwd
    ip6tables -w -t mangle -D FORWARD -i ${tap} -j DROP 2>/dev/null || true
    ip6tables -w -t mangle -I FORWARD -i ${tap} -j DROP
  '';
  networking.firewall.extraStopCommands = ''
    ip46tables -w -D INPUT -i ${tap} -j agent-vm-in 2>/dev/null || true
    ip46tables -w -F agent-vm-in 2>/dev/null || true
    ip46tables -w -X agent-vm-in 2>/dev/null || true
    iptables -w -t mangle -D FORWARD -i ${tap} -j agent-vm-fwd 2>/dev/null || true
    iptables -w -t mangle -F agent-vm-fwd 2>/dev/null || true
    iptables -w -t mangle -X agent-vm-fwd 2>/dev/null || true
    ip6tables -w -t mangle -D FORWARD -i ${tap} -j DROP 2>/dev/null || true
  '';

  networking.hosts.${guestAddr} = [ "agent-vm" ];
}
