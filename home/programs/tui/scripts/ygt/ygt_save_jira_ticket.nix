{ pkgs, ... }:

pkgs.writeShellScriptBin "ygt_save_jira_ticket" ''
  BRANCH=$(git branch --show-current)
  OUTPUT_DIR=.agents/$BRANCH

  mkdir -p $OUTPUT_DIR

  ygt_fetch_jira_ticket "''${1:-}" > $OUTPUT_DIR/ticket.json
''
