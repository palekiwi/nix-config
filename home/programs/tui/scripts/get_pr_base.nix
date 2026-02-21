{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_base" ''
  if [[ -f .gh_pr_base ]]; then
    cat .gh_pr_base
  else
    exit 1
  fi
''
