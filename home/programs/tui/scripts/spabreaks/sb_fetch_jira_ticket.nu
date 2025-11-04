def main [ticket?: string] {
    let ticket = if $ticket != null {
        $ticket
    } else {
        spabreaks_jira_ticket_from_branch
    }

    let api_url = $"($env.JIRA_URL)/rest/api/2/issue/($ticket)"

    let response = (
        http get
            --user $env.JIRA_EMAIL --password $env.JIRA_TOKEN
            --headers [Content-Type application/json]
            $"($api_url)?expand=renderedFields"
    )


    $response
    | {
         title: $in.fields.summary,
         description: $in.renderedFields.description,
         technical_notes: $in.renderedFields.customfield_10174
    }
}
