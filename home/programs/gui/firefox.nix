{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.firefox;
in
{
  options.modules.firefox = {
    enable = mkEnableOption "enable firefox";
  };

  config = mkIf cfg.enable {
    programs.firefox = {
        enable = true;
    };
  };
}
