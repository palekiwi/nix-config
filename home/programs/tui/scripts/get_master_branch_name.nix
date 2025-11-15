{ pkgs, ... }:

pkgs.writeShellScriptBin "get_master_branch_name" ''
  # Get the default branch name of the git repository, fallback to "master"
  get_default_branch() {
    ${pkgs.git}/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | ${pkgs.gnused}/bin/sed 's@^refs/remotes/origin/@@'
  }

  if ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
    DEFAULT_BRANCH=$(get_default_branch)

    # If no remote HEAD is set, try to set it automatically
    if [ -z "$DEFAULT_BRANCH" ]; then
      ${pkgs.git}/bin/git remote set-head origin -a >/dev/null 2>&1
      DEFAULT_BRANCH=$(get_default_branch)
    fi

    # If still no result, fallback to "master"
    echo "''${DEFAULT_BRANCH:-master}"
  fi
''
