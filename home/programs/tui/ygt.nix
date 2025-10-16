{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.ygt;

  projectConfigs = {
    my-account = {
      envrc = ../../config/ygt/my-account/.envrc;
      gitHooks = {
        post-checkout = ../../config/ygt/git/hooks/post-checkout;
        post-merge = ../../config/ygt/git/hooks/post-merge;
      };
    };
    sb-voucher-redemptions = {
      envrc = ../../config/ygt/sb-voucher-redemptions/.envrc;
      gitHooks = {
        post-checkout = ../../config/ygt/git/hooks/post-checkout;
        post-merge = ../../config/ygt/git/hooks/post-merge;
      };
    };
    spabreaks = {
      envrc = ../../config/ygt/spabreaks/.envrc;
      gitHooks = {
        pre-commit = ../../config/ygt/spabreaks/git/hooks/pre-commit;
        post-checkout = ../../config/ygt/git/hooks/post-checkout;
        post-merge = ../../config/ygt/git/hooks/post-merge;
      };
    };
    spabreak-terraform = {
      envrc = ../../config/ygt/spabreak-terraform/.envrc;
      gitHooks = {
        post-checkout = ../../config/ygt/git/hooks/post-checkout;
        post-merge = ../../config/ygt/git/hooks/post-merge;
      };
    };
  };

  commonYgtFiles = {
    "code/ygt/.envrc".source = ../../config/ygt/.envrc;
    "code/ygt/.gitconfig".source = ../../config/ygt/.gitconfig;
    "code/ygt/.gitignore".text = import ../../config/ygt/.gitignore.nix;
  };

  mkProjectFiles = projectName: config: let
    basePath = "code/ygt/${projectName}";
  in
    (lib.optionalAttrs (config ? envrc) {
      "${basePath}/.envrc".source = config.envrc;
    }) // (lib.optionalAttrs (config ? gitHooks) (
      lib.mapAttrs' (hookName: hookPath:
        lib.nameValuePair "${basePath}/.git/hooks/${hookName}" { source = hookPath; }
      ) config.gitHooks
    ));

  allProjectFiles = lib.foldl' (acc: name:
    acc // (mkProjectFiles name projectConfigs.${name})
  ) {} (builtins.attrNames projectConfigs);
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
      (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
      sops
    ] ++ lib.optionals config.gui [
      slack
    ] ++ (import ./scripts/spabreaks/default.nix { inherit pkgs; });

    home.file = commonYgtFiles // allProjectFiles;
  };
}
