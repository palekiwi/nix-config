{ pkgs, ... }:

pkgs.writeShellScriptBin "ygt_fetch_jira_ticket" ''
  # Use provided ticket or get from branch
  TICKET="''${1:-$(ygt_jira_ticket_from_branch)}"

  # Construct the API URL
  API_URL="$JIRA_URL/rest/api/2/issue/$TICKET"

  # Make the API request and extract the description
  curl -s -u "$JIRA_EMAIL:$JIRA_TOKEN" -X GET -H "Content-Type: application/json" "$API_URL?expand=renderedFields" \
    | jq -r '{title: .fields.summary, description: .renderedFields.description, technical_notes: .renderedFields.customfield_10136}'
''
