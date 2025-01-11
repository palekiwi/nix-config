{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.ygt;
in
{
  options.modules.ygt = {
    enable = mkEnableOption "enable ygt";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      docker-compose
      gcc
      gnumake
      go-task
      google-cloud-sdk
      slack
      sops
    ];
  };
}
