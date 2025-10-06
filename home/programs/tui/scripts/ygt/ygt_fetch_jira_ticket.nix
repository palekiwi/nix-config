{ pkgs, ... }:

pkgs.writeShellScriptBin "ygt_fetch_jira_ticket" ''
  TICKET_URL=$1

  if [ -z "$TICKET_URL" ]; then
    echo "Usage: $0 <jira-ticket-url>"
    exit 1
  fi

  TICKET_KEY=$(echo "$TICKET_URL" | sed 's/.*\/browse\///')

  if [ -z "$TICKET_KEY" ]; then
    echo "Could not extract ticket key from URL: $TICKET_URL"
    exit 1
  fi

  # Construct the API URL
  API_URL="$JIRA_URL/rest/api/2/issue/$TICKET_KEY"

  # Make the API request and extract the description
  curl -s -u "$JIRA_EMAIL:$JIRA_TOKEN" -X GET -H "Content-Type: application/json" "$API_URL?expand=renderedFields" | jq -r '.renderedFields.description'
''
