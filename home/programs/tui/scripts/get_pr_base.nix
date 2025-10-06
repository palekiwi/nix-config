{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_base" ''
  if [[ -f .git/GIT_BASE ]]; then
    cat .git/GIT_BASE
  else
    exit 1
  fi
''
