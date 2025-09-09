{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_base" ''
  if [[ -f .git/pr-info ]]; then
    source .git/pr-info
    echo "$GIT_BASE"
  fi
''
