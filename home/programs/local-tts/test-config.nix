{ pkgs, home-manager }:
let
  evaluate =
    enabled:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./default.nix
        {
          home.username = "tts-test";
          home.homeDirectory = "/home/tts-test";
          home.stateVersion = "24.11";
          programs.local-tts.enable = enabled;
        }
      ];
    };
  enabled = evaluate true;
  disabled = evaluate false;
  speechPackages =
    configuration:
    builtins.filter (package: (package.pname or "") == "local-tts") configuration.config.home.packages;
in
assert builtins.length (speechPackages enabled) == 1;
assert speechPackages disabled == [ ];
assert enabled.config.systemd.user.services == { };
{
  enabled = enabled.activationPackage.drvPath;
  disabled = disabled.activationPackage.drvPath;
  package = (builtins.head (speechPackages enabled)).outPath;
}
