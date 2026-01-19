let
  globalIgnores = builtins.concatStringsSep "\n" (import ../../programs/tui/gitignores.nix);
in

''
  # Global ignores
  ${globalIgnores}

  # Spabreaks-specific ignores
  .envrc
  .gutctags
  .opencode
  .agents
  AGENTS.md
  ai_docs
  gemset.nix
  ocx.json
  ocx.env
  opencode.json
  cypress/cypress/screenshots
  cypress/cypress/snapshots
''
