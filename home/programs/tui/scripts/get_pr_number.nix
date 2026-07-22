{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_number" ''
  GIT_DIR=$(${pkgs.git}/bin/git rev-parse --git-dir 2>/dev/null) || exit 1
  if [[ -f "$GIT_DIR/GH_PR_NUMBER" ]]; then
    cat "$GIT_DIR/GH_PR_NUMBER"
  else
    exit 1
  fi
''
