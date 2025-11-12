{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.spabreaks;

  projectConfigs = {
    booking-transform = {
      envrc = ../../config/spabreaks/booking-transform/.envrc;
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    my-account = {
      envrc = ../../config/spabreaks/my-account/.envrc;
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    sb-voucher-redemptions = {
      envrc = ../../config/spabreaks/sb-voucher-redemptions/.envrc;
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    spabreaks = {
      envrc = ../../config/spabreaks/spabreaks/.envrc;
      gitHooks = {
        pre-commit = ../../config/spabreaks/spabreaks/git/hooks/pre-commit;
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    spabreak-terraform = {
      envrc = ../../config/spabreaks/spabreak-terraform/.envrc;
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
  };

  commonSpabreaksFiles = {
    "code/spabreaks/.envrc".source = ../../config/spabreaks/.envrc;
    "code/spabreaks/.gitconfig".source = ../../config/spabreaks/.gitconfig;
    "code/spabreaks/.gitignore".text = import ../../config/spabreaks/.gitignore.nix;
  };

  mkProjectFiles = projectName: config: let
    basePath = "code/spabreaks/${projectName}";
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
  options.modules.spabreaks = {
    enable = mkEnableOption "enable Spabreaks";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      docker-compose
      gcc
      gnumake
      go-task
      (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
      sops
      terraform-ls
    ] ++ lib.optionals config.gui [
      slack
    ] ++ (import ./scripts/spabreaks/default.nix { inherit pkgs; });

    home.file = commonSpabreaksFiles // allProjectFiles;
  };
}
