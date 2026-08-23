{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_base" ''
  branch=$(${pkgs.git}/bin/git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -n "$branch" ]; then
    base=$(${pkgs.git}/bin/git config "branch.''${branch}.base" 2>/dev/null || true)
    if [ -n "$base" ]; then
      echo "$base"
      exit 0
    fi
  fi

  remote_head=$(${pkgs.git}/bin/git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$remote_head" ]; then
    base="''${remote_head#origin/}"
    if [ -n "$base" ]; then
      echo "$base"
      exit 0
    fi
  fi

  if ${pkgs.git}/bin/git show-ref --quiet --verify refs/heads/main 2>/dev/null || \
     ${pkgs.git}/bin/git show-ref --quiet --verify refs/remotes/origin/main 2>/dev/null; then
    echo "main"
    exit 0
  fi

  if ${pkgs.git}/bin/git show-ref --quiet --verify refs/heads/master 2>/dev/null || \
     ${pkgs.git}/bin/git show-ref --quiet --verify refs/remotes/origin/master 2>/dev/null; then
    echo "master"
    exit 0
  fi

  echo "master"
  exit 0
''
