let
  globalIgnores = builtins.concatStringsSep "\n" (import ../../programs/tui/gitignores.nix);
in

''
  # Global ignores
  ${globalIgnores}

  # OSS-specific ignores (files commonly found in Nix/dev environments)
  .envrc
  .opencode
  opencode.json
  flake.nix
  flake.lock
  Taskfile.yml
  .sops.yaml
  .gutctags
  AGENTS.md
  gemset.nix
  result
  result-*
  shell.nix
  default.nix
''