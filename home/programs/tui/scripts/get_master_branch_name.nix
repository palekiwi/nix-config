{ pkgs, ... }:

pkgs.writeShellScriptBin "get_master_branch_name" ''
  # Get the default branch name of the git repository, fallback to "master"
  if ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
    ${pkgs.git}/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
      | ${pkgs.gnused}/bin/sed 's@^refs/remotes/origin/@@' \
      || echo "master"
  fi
''
