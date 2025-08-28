{ pkgs, ... }:

let
  gitConfig = {
    userName = "Pawel Lisewski";
    userEmail = "dev@palekiwi.com";
    signing = {
      key = "848E5BB30B98EB1D2714BCCB44766C74B3546A52";
      signByDefault = true;
    };
    ignores = [
      "*.swp"
      ".direnv"
      "build"
      "log/test.log.0"
      "tags"
      "tags.lock"
      "tags.temp"
      "tmux-client-*"
      "vendor"
    ];
    extraConfig = {
      init.defaultBranch = "master";
      pull.rebase = true;
    };
  };

  # Convert ignores list to gitignore format
  globalIgnores = builtins.concatStringsSep "\n" gitConfig.ignores;

in
{
  home.packages = with pkgs; [ git gitui ];

  programs.git = gitConfig // { enable = true; };

  # Org-specific files
  home.file."code/ygt/.gitignore".text = ''
    # Global ignores
    ${globalIgnores}

    # YGT-specific ignores
      ".envrc"
      ".gutctags"
      "gemset.nix"
      "AGENTS.md"
      ".opencode"
      ""
  '';

  home.file."code/ygt/.gitconfig".text = ''
    [user]
        name = ${gitConfig.userName}
        email = ${gitConfig.userEmail}
    [commit]
        gpgsign = ${if gitConfig.signing.signByDefault then "true" else "false"}
    [user]
        signingkey = ${gitConfig.signing.key}
    [init]
        defaultBranch = ${gitConfig.extraConfig.init.defaultBranch}
    [pull]
        rebase = ${if gitConfig.extraConfig.pull.rebase then "true" else "false"}
    [core]
        excludesfile = ~/code/ygt/.gitignore
  '';
}
