{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.spabreaks;

  projectConfigs = {
    booking-transform = {
      files = {
        ".envrc" = ../../config/spabreaks/booking-transform/.envrc;
      };
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    my-account = {
      files = {
        ".envrc" = ../../config/spabreaks/my-account/.envrc;
      };
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    voucher-portal = {
      files = {
        ".envrc" = ../../config/spabreaks/voucher-portal/.envrc;
      };
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    spabreaks = {
      files = {
        ".envrc" = ../../config/spabreaks/spabreaks/.envrc;
        "ocx.env" = ../../config/spabreaks/spabreaks/ocx.env;
      };
      gitHooks = {
        pre-commit = ../../config/spabreaks/spabreaks/git/hooks/pre-commit;
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    agents-spabreaks = {
      gitHooks = {
        pre-commit = ../../config/spabreaks/spabreaks/git/hooks/pre-commit;
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    terraform = {
      files = {
        ".envrc" = ../../config/spabreaks/terraform/.envrc;
      };
      gitHooks = {
        post-checkout = ../../config/spabreaks/git/hooks/post-checkout;
        post-merge = ../../config/spabreaks/git/hooks/post-merge;
      };
    };
    gemini-cli-tool = {
      files = {
        ".envrc" = ../../config/spabreaks/gemini-cli-tool/.envrc;
      };
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
    (lib.optionalAttrs (config ? files) (
      lib.mapAttrs' (fileName: filePath:
        lib.nameValuePair "${basePath}/${fileName}" { source = filePath; }
      ) config.files
    ))
    // (lib.optionalAttrs (config ? gitHooks) (
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
      (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
      lastpass-cli
      sops
      terraform-ls
    ] ++ lib.optionals config.gui [
      slack
    ] ++ (import ./scripts/spabreaks/default.nix { inherit pkgs; });

    home.file = commonSpabreaksFiles // allProjectFiles;
  };
}
