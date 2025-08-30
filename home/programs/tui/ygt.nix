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

      "code/ygt/sb-voucher-redemptions/.envrc".source = ../../config/ygt/sb-voucher-redemptions/.envrc;

      "code/ygt/spabreaks/.envrc".source = ../../config/ygt/spabreaks/.envrc;
      "code/ygt/spabreaks/.git/hooks/pre-commit".source = ../../config/ygt/spabreaks/git/hooks/pre-commit;
      "code/ygt/spabreaks/.git/hooks/post-checkout".source = ../../config/ygt/spabreaks/git/hooks/post-checkout;
      "code/ygt/spabreaks/.git/hooks/post-merge".source = ../../config/ygt/spabreaks/git/hooks/post-merge;
    };
  };
}
