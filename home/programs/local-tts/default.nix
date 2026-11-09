{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.programs.local-tts = {
    enable = lib.mkEnableOption "foreground local text-to-speech";
    backend = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "http"
      ];
      default = "cpu";
      description = "Default speech backend; failures never select another backend.";
    };
  };
  config = lib.mkIf config.programs.local-tts.enable {
    home.packages = [
      (pkgs.callPackage ./package.nix { inherit (config.programs.local-tts) backend; })
    ];
  };
}
