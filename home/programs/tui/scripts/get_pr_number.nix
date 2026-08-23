{ pkgs, ... }:

pkgs.writeShellScriptBin "get_pr_number" ''
  branch=$(${pkgs.git}/bin/git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -z "$branch" ]; then
    exit 1
  fi
  pr_number=$(${pkgs.git}/bin/git config "branch.''${branch}.pr" 2>/dev/null || true)
  if [ -n "$pr_number" ]; then
    echo "$pr_number"
    exit 0
  else
    exit 1
  fi
''
