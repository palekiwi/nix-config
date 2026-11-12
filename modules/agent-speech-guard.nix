{ lib, ... }:
let
  tap = "vm-agent";
  guestAddr = "10.77.0.2";
  endpoint = import ../home/programs/local-tts/bridge-endpoint.nix;
  listenAddr = endpoint.host;
  port = toString endpoint.port;
in
{
  networking.firewall.extraCommands = lib.mkAfter ''
    iptables -w -D INPUT -p tcp --dport ${port} -j agent-speech-guard 2>/dev/null || true
    iptables -w -N agent-speech-guard 2>/dev/null || true
    iptables -w -F agent-speech-guard
    iptables -w -A agent-speech-guard -i ${tap} -s ${guestAddr} -d ${listenAddr} -j ACCEPT
    iptables -w -A agent-speech-guard -j DROP
    iptables -w -I INPUT -p tcp --dport ${port} -j agent-speech-guard
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D INPUT -p tcp --dport ${port} -j agent-speech-guard 2>/dev/null || true
    iptables -w -F agent-speech-guard 2>/dev/null || true
    iptables -w -X agent-speech-guard 2>/dev/null || true
  '';
}
