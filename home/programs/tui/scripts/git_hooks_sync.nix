{ pkgs }:

pkgs.writeShellScriptBin "git-hooks-sync" (builtins.readFile ./git-hooks-sync.sh)
