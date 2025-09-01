{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_number" ''
  if [[ -f .git/pr-info ]]; then
    source .git/pr-info
    echo "$GH_PR_NUMBER"
  fi
''
