{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_base" ''
  GIT_DIR=$(${pkgs.git}/bin/git rev-parse --git-dir 2>/dev/null) || exit 1
  if [[ -f "$GIT_DIR/GIT_BASE" ]]; then
    cat "$GIT_DIR/GIT_BASE"
  else
    exit 1
  fi
''
