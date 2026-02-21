{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_number" ''
  if [[ -f .gh_pr_number ]]; then
    cat .gh_pr_number
  else
    exit 1
  fi
''
