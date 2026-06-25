{ pkgs, config, ... }:

let
  nixConfigPath = "${config.home.homeDirectory}/nix-config";
  gitHooksSource = "${nixConfigPath}/home/config/git/hooks";
in

{
  home.packages = with pkgs; [ git gitui ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Pawel Lisewski";
        email = "dev@palekiwi.com";
      };
      init.defaultBranch = "master";
      pull.rebase = true;
      init.templateDir = "${config.xdg.configHome}/git/templates";
    };
    signing = {
      key = "848E5BB30B98EB1D2714BCCB44766C74B3546A52";
      signByDefault = true;
    };
    ignores = import ./gitignores.nix;
  };

  home.file = {
    "${config.xdg.configHome}/git/templates/hooks/post-checkout".source =
      config.lib.file.mkOutOfStoreSymlink "${gitHooksSource}/post-checkout";

    "${config.xdg.configHome}/git/templates/hooks/post-merge".source =
      config.lib.file.mkOutOfStoreSymlink "${gitHooksSource}/post-merge";
  };
}
