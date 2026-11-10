{ pkgs, home-manager }:
let
  evaluate =
    enabled: backend:
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
          };
        }
      ];
    };
  enabled = evaluate true "cpu";
  http = evaluate true "http";
  disabled = evaluate false "cpu";
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
{
  enabled = enabled.activationPackage.drvPath;
  disabled = disabled.activationPackage.drvPath;
  http = http.activationPackage.drvPath;
  package = (builtins.head (speechPackages enabled)).outPath;
}
