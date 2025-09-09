{ pkgs, config, ... }:

{
  home.packages = with pkgs; [ git gitui ];

  programs.git = {
    enable = true;
    userName = "Pawel Lisewski";
    userEmail = "dev@palekiwi.com";
    signing = {
      key = "848E5BB30B98EB1D2714BCCB44766C74B3546A52";
      signByDefault = true;
    };
    ignores = import ./gitignores.nix;
    extraConfig = {
      init.defaultBranch = "master";
      pull.rebase = true;
      core.hooksPath = "${config.xdg.configHome}/git/hooks";
    };
  };

  home.file = {
    "${config.xdg.configHome}/git/hooks/post-checkout".source = ../../config/git/hooks/post-checkout;
    "${config.xdg.configHome}/git/hooks/post-merge".source = ../../config/git/hooks/post-merge;
    "${config.xdg.configHome}/git/hooks/pre-commit".source = ../../config/git/hooks/pre-commit;
  };
}
