export def "ticket url" [--org = "spabreaks", --id = "SB", --open] {
    let number = git rev-parse --abbrev-ref HEAD
        | str trim
        | parse --regex '(?<number>\d{4,5})'
        | get number.0

    let $url = $"https://($org).atlassian.net/browse/($id)-($number)"

    if $open { xdg-open $url }

    $url
}

export def "ticket view" [ticket?: string, --json] {
    let data = ticket fetch $ticket
    if $json { $data } else { ticket-to-md $data }
}

def ticket-to-md [data: record] {
    let ticket = $data.ticket
    $data
    | reject ticket
    | items { |key, value| {key: $key, value: ($value | pandoc -f html -t markdown --shift-heading-level-by=1) }}
    | $"# [($ticket)] ($in.0.value)\n\n---\n\n## Description\n\n($in.1.value)\n\n## Technical Notes\n\n($in.2.value)"
}

export def "ticket save" [ticket?: string, --json] {
    let ticket = if $ticket != null {
        $ticket
    } else {
        spabreaks_jira_ticket_from_branch
    }

    let data = ticket fetch $ticket
    let content = if $json { $data } else { ticket-to-md $data }

    mem add $"tickets/($ticket).md" $content
}

export def "ticket fetch" [ticket?: string] {
    let ticket = if $ticket != null {
        $ticket
    } else {
        spabreaks_jira_ticket_from_branch
    }

    let api_url = $"($env.JIRA_URL)/rest/api/2/issue/($ticket)"

    (
        http get
            --user $env.JIRA_EMAIL --password $env.JIRA_TOKEN
            --headers [Content-Type application/json]
            $"($api_url)?expand=renderedFields"
    )
    | {
         ticket: $ticket,
         title: $in.fields.summary,
         description: $in.renderedFields.description,
         technical_notes: $in.renderedFields.customfield_10174
    }
}

export def "test" [...args] {
    let result = do { go-task test -- --format json ...$args } | complete
    let stdout = $result.stdout

    if ($stdout | is-empty) {
        if ($result.stderr | is-not-empty) {
            print -e $result.stderr
        }
        return
    }

    let failed = $stdout | from json | get examples | where $it.status == "failed"

    mem add --tmp -f rspec-failures.json ($failed | to json)
}

# TODO: rewrite this in nushell
export alias "pr create" = sb-create-pr
