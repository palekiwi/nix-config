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

    home.file = {
      "code/ygt/.envrc".source = ../../config/ygt/.envrc;
      "code/ygt/.gitconfig".source = ../../config/ygt/.gitconfig;
      "code/ygt/.gitignore".text = import ../../config/ygt/.gitignore.nix;
      "code/ygt/spabreaks/.envrc".source = ../../config/ygt/spabreaks/.envrc;
    };
  };
}
