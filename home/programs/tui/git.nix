{ config, pkgs, ... }:

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
    ignores = [
      "*.swp"
      ".direnv"
      ".envrc"
      ".gutctags"
      "build"
      "gemset.nix"
      "log/test.log.0"
      "tags"
      "tags.lock"
      "tags.temp"
      "tmux-client-*"
      "vendor"
    ];
    # hooks = {
    #   pre-commit = ../config/git/hooks/pre-commit;
    # };
    extraConfig = {
      init.defaultBranch = "master";
      pull.rebase = true;
    };
  };
}
