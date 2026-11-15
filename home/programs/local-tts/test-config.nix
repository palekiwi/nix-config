{ pkgs, home-manager }:
let
  inherit (pkgs) lib;
  evaluate =
    enabled: backend: bridge: target:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./default.nix
        {
          home.username = "tts-test";
          home.homeDirectory = "/home/tts-test";
          home.stateVersion = "24.11";
          programs.local-tts = {
            enable = enabled;
            inherit backend target;
            bridge.enable = bridge;
            bridge.natsUrl = if bridge && enabled then "nats://127.0.0.1:4222" else null;
          };
        }
      ];
    };
  enabled = evaluate true "cpu" false null;
  http = evaluate true "http" false null;
  disabled = evaluate false "cpu" false null;
  bridged = evaluate false "http" true null;
  targeted = evaluate true "cpu" false "bluez_output.sink";
  unified = evaluate true "http" true null;
  bridge = bridged.config.systemd.user.services.speech-bridge;
  endpoint = import ./bridge-endpoint.nix;
  speechPackages =
    configuration:
    builtins.filter (package: (package.pname or "") == "local-tts") configuration.config.home.packages;
  installPhase = configuration: (builtins.head (speechPackages configuration)).installPhase;
  targetFlag = "--set-default SPEAK_TARGET ${lib.escapeShellArg "bluez_output.sink"}";
in
assert builtins.length (speechPackages enabled) == 1;
assert speechPackages disabled == [ ];
assert disabled.config.systemd.user.services == { };
assert builtins.attrNames enabled.config.systemd.user.services == [ "clipboard-speech" ];
assert enabled.config.systemd.user.services.clipboard-speech.Service.KillMode == "control-group";
assert enabled.config.systemd.user.services.clipboard-speech.Service.Type == "exec";
assert enabled.config.systemd.user.services.clipboard-speech.Unit.StartLimitIntervalSec == 0;
assert !(enabled.config.systemd.user.services.clipboard-speech ? Install);
assert builtins.length (speechPackages http) == 1;
assert
  http.config.systemd.user.services.clipboard-speech.Service.ExecStart
  == [ "${builtins.head (speechPackages http)}/bin/speak --clipboard" ];
assert
  (builtins.head (speechPackages http)).drvPath != (builtins.head (speechPackages enabled)).drvPath;
assert builtins.length (speechPackages targeted) == 1;
assert
  (builtins.head (speechPackages enabled)).drvPath == (pkgs.callPackage ./package.nix { }).drvPath;
assert !(lib.hasInfix "SPEAK_TARGET" (installPhase enabled));
assert builtins.length (lib.splitString targetFlag (installPhase targeted)) == 3;
assert builtins.attrNames unified.config.systemd.user.services == [ "speech-bridge" ];
assert speechPackages bridged == [ ];
assert builtins.attrNames bridged.config.systemd.user.services == [ "speech-bridge" ];
assert bridge.Install.WantedBy == [ "default.target" ];
assert bridge.Unit.After == [ "pipewire.service" ];
assert bridge.Service.Restart == "on-failure";
assert bridge.Service.RestartSec == 2;
assert
  endpoint == {
    host = "10.77.0.1";
    port = 8881;
  };
assert
  builtins.match ".*/bin/speech-bridge --host 10\\.77\\.0\\.1 --port 8881 --voice af_bella --speed 1\\.0+ --max-chars 1000 --max-queue 64" (
    builtins.head bridge.Service.ExecStart
  ) != null;
{
  enabled = enabled.activationPackage.drvPath;
  disabled = disabled.activationPackage.drvPath;
  http = http.activationPackage.drvPath;
  bridged = bridged.activationPackage.drvPath;
  targeted = targeted.activationPackage.drvPath;
  package = (builtins.head (speechPackages enabled)).outPath;
}
