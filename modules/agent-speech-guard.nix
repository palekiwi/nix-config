{ lib, ... }:
let
  endpoint = import ../home/programs/local-tts/bridge-endpoint.nix;
  guard = import ./agent-port-guard.nix {
    name = "agent-speech-guard";
    inherit (endpoint) port;
    tap = "vm-agent";
    guestAddr = "10.77.0.2";
    listenAddr = endpoint.host;
    allowLocal = true;
  };
in
{
  networking.firewall.extraCommands = lib.mkAfter guard.start;
  networking.firewall.extraStopCommands = guard.stop;
}
