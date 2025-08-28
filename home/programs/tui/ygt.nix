{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.ygt;

  globalIgnores = builtins.concatStringsSep "\n" (import ./gitignores.nix);
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

    # :: Environment ::
    home.file."code/ygt/spabreaks/.envrc" = {
      source = ../../config/ygt/spabreaks/.envrc;
    };

    # :: Git Configuration ::
    home.file."code/ygt/.gitignore".text = ''
      # Global ignores
      ${globalIgnores}

      # YGT-specific ignores
      .envrc
      .gutctags
      .opencode
      AGENTS.md
      gemset.nix
    '';

    home.file."code/ygt/.gitconfig".text = ''
      [user]
          name = Pawel Lisewski
          email = dev@palekiwi.com
          signingkey = 848E5BB30B98EB1D2714BCCB44766C74B3546A52
      [commit]
          gpgsign = true
      [init]
          defaultBranch = master
      [pull]
          rebase = true
      [core]
          excludesfile = ~/code/ygt/.gitignore
    '';
  };
}
