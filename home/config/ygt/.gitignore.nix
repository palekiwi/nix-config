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
  .agents
  AGENTS.md
  gemset.nix
  opencode.json
  cypress/cypress/screenshots
  cypress/cypress/snapshots
''
