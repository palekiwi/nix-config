{ pkgs, ... }:

let
  gitConfig = {
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
    };
  };
in

{
  home.packages = with pkgs; [ git gitui ];

  programs.git = gitConfig // { enable = true; };
}
