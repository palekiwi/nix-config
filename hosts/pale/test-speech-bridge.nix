{ flake }:
let
  config = flake.nixosConfigurations.pale.config;
  lib = flake.inputs.nixpkgs.lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  endpoint = import ../../home/programs/local-tts/bridge-endpoint.nix;
  home = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../home/programs/local-tts
      {
        home.username = "pl";
        home.homeDirectory = "/home/pl";
        home.stateVersion = "24.11";
        programs.local-tts.bridge.enable = true;
      }
    ];
  };
  bridge = home.config.systemd.user.services.speech-bridge;
  lines = text: lib.filter (line: line != "") (map lib.trim (lib.splitString "\n" text));
  start = lines config.networking.firewall.extraCommands;
  stop = lines config.networking.firewall.extraStopCommands;
  guard = [
    "iptables -w -D INPUT -p tcp --dport 8881 -j agent-speech-guard 2>/dev/null || true"
    "iptables -w -N agent-speech-guard 2>/dev/null || true"
    "iptables -w -F agent-speech-guard"
    "iptables -w -A agent-speech-guard -i vm-agent -s 10.77.0.2 -d 10.77.0.1 -j ACCEPT"
    "iptables -w -A agent-speech-guard -j DROP"
    "iptables -w -I INPUT -p tcp --dport 8881 -j agent-speech-guard"
  ];
  cleanup = [
    "iptables -w -D INPUT -p tcp --dport 8881 -j agent-speech-guard 2>/dev/null || true"
    "iptables -w -F agent-speech-guard 2>/dev/null || true"
    "iptables -w -X agent-speech-guard 2>/dev/null || true"
  ];
  indexOf =
    line:
    let
      found = lib.lists.findFirstIndex (candidate: candidate == line) null start;
    in
    assert found != null;
    found;
  sublist =
    needle: haystack:
    lib.any (i: lib.sublist i (lib.length needle) haystack == needle) (
      lib.range 0 (lib.length haystack)
    );
in
assert
  endpoint == {
    host = "10.77.0.1";
    port = 8881;
  };
assert config.networking.firewall.enable;
assert !config.networking.nftables.enable;
assert sublist guard start;
assert sublist cleanup stop;
assert
  indexOf "iptables -w -I INPUT -p tcp --dport 8881 -j agent-speech-guard"
  > indexOf "ip46tables -w -I INPUT -i vm-agent -j agent-vm-in";
assert !(lib.elem 8881 config.networking.firewall.allowedTCPPorts);
assert lib.hasInfix "--host 10.77.0.1 --port 8881 " (builtins.head bridge.Service.ExecStart);
{
  system = config.system.build.toplevel.drvPath;
  extraCommands = config.networking.firewall.extraCommands;
  bridge = builtins.head bridge.Service.ExecStart;
}
