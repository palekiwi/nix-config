{ pkgs, home-manager }:
let
  evaluate =
    enabled: backend: bridge:
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
            inherit backend;
            bridge.enable = bridge;
          };
        }
      ];
    };
  enabled = evaluate true "cpu" false;
  http = evaluate true "http" false;
  disabled = evaluate false "cpu" false;
  bridged = evaluate false "http" true;
  bridge = bridged.config.systemd.user.services.speech-bridge;
  endpoint = import ./bridge-endpoint.nix;
  speechPackages =
    configuration:
    builtins.filter (package: (package.pname or "") == "local-tts") configuration.config.home.packages;
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
  package = (builtins.head (speechPackages enabled)).outPath;
}
