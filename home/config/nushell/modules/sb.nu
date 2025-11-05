export def "ticket url" [--org = "spabreaks", --id = "SB", --open] {
    let number = git rev-parse --abbrev-ref HEAD
        | str trim
        | parse --regex '(?<number>\d{4,5})'
        | get number.0

    let $url = $"https://($org).atlassian.net/browse/($id)-($number)"

    if $open { xdg-open $url }

    $url
}

export def "ticket view" [ticket?: string, --json, --save] {
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


    let filtered = $response
    | {
         title: $in.fields.summary,
         description: $in.renderedFields.description,
         technical_notes: $in.renderedFields.customfield_10174
    }

    let content = if $json {
        $filtered
    } else {
        $filtered
        | items { |key, value| {key: $key, value: ($value | pandoc -f html -t markdown --shift-heading-level-by=1) }}
        | $"# ($in.0.value)\n\n---\n\n## Description\n\n($in.1.value)\n\n## Technical Notes\n\n($in.2.value)"
    }


    if $save {
        let branch = git branch --show-current
        let output_dir = $".agents/($branch)"
        let ext = if $json { "json" } else { "md" }
        let filename = $"ticket.($ext)"

        mkdir $output_dir

        let target = $"($output_dir)/($filename)"

        $content | save -f $target

        $target

    } else {
        $content
    }
}
