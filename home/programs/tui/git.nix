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
      alias.vm-wip = ''!f() { u=$(git remote get-url vm) && h=''${u%%:*} && p=''${u#*:} && r=$(ssh "$h" "git -C '$p' rev-parse HEAD") && [ "$r" = "$(git rev-parse HEAD)" ] || { echo "vm HEAD $r differs from local HEAD; run git vm-pull first" >&2; return 1; }; ssh "$h" "cd '$p' && t=\$(mktemp) && cp \$(git rev-parse --git-path index) \$t 2>/dev/null; GIT_INDEX_FILE=\$t git add -A && GIT_INDEX_FILE=\$t git diff --cached --binary HEAD; rm -f \$t" | git apply --index --stat --apply "$@"; }; f'';
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
