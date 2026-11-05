{ pkgs, config, ... }:

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
      merge.ff = "only";
      alias.vm-pull = ''!f() { b=$(git symbolic-ref --short HEAD) && git fetch vm && git log --oneline "HEAD..vm/$b" && git merge --ff-only "vm/$b"; }; f'';
      # Template entries must be real files: git copies template entries
      # verbatim, and home.file can only produce symlinks - which dangle
      # after store GC and never resolve inside cast containers.
      init.templateDir =
        "${config.home.homeDirectory}/nix-config/home/config/git/templates";
    };
    signing = {
      key = "848E5BB30B98EB1D2714BCCB44766C74B3546A52";
      signByDefault = true;
    };
    ignores = import ./gitignores.nix;
  };
}
