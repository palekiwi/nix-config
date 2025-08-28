let
  globalIgnores = builtins.concatStringsSep "\n" (import ../../programs/tui/gitignores.nix);
in

''
  # Global ignores
  ${globalIgnores}

  # YGT-specific ignores
  .envrc
  .gutctags
  .opencode
  AGENTS.md
  gemset.nix
''
