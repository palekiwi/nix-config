{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_number" ''
  if [[ -f .git/GH_PR_NUMBER ]]; then
    cat .git/GH_PR_NUMBER
  else
    exit 1
  fi
''
