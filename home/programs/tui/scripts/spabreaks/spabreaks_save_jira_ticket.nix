{ pkgs, ... }:

pkgs.writeShellScriptBin "spabreaks_save_jira_ticket" ''
  BRANCH=$(git branch --show-current)
  OUTPUT_DIR=.agents/$BRANCH

  mkdir -p $OUTPUT_DIR

  spabreaks_fetch_jira_ticket "''${1:-}" > $OUTPUT_DIR/ticket.json
''
