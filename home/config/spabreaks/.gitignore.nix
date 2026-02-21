let
  globalIgnores = builtins.concatStringsSep "\n" (import ../../programs/tui/gitignores.nix);
in

''
  # Global ignores
  ${globalIgnores}

  # Spabreaks-specific ignores
  .envrc
  .gutctags
  .agents
  ai_docs
  gemset.nix
  cypress/cypress/screenshots
  cypress/cypress/snapshots
''
