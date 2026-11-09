{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.programs.local-tts.enable = lib.mkEnableOption "foreground local text-to-speech";
  config = lib.mkIf config.programs.local-tts.enable {
    home.packages = [ (pkgs.callPackage ./package.nix { }) ];
  };
}
