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

# Ensure the scope-wide `jira` context exists. `cue context create` has no
# idempotency flag and exits 1 on an existing context, so the check is ours.
def ensure-jira-context [] {
    let listed = do { cue context list } | complete

    if $listed.exit_code != 0 {
        error make {msg: $"cue context list failed: ($listed.stderr | str trim)"}
    }

    if ($listed.stdout | lines | any {|slug| ($slug | str trim) == "jira"}) {
        return
    }

    let created = do {
        (
            cue context create jira
                --kind reference
                --title "Jira"
                --description "Mirror of Jira tickets, epics and sprints"
        )
    } | complete

    if $created.exit_code != 0 {
        error make {msg: $"cue context create jira failed: ($created.stderr | str trim)"}
    }
}

# Mirror a Jira ticket into the `jira` context as
# `spec/tickets/<TICKET>.md`.
#
# One canonical copy, referenced from every context that works the ticket.
# This deliberately creates no work context: a ticket may be served by a
# review, a design and a build context at once, and which of those it needs
# is unknown at fetch time, so the mirror must not assume a shape.
#
# Refetching an existing mirror requires --force, and `cue add` replaces the
# file wholesale, so `created_at` is re-stamped to the refetch time.
export def "ticket save" [ticket?: string, --force] {
    let ticket = if $ticket != null {
        $ticket
    } else {
        spabreaks_jira_ticket_from_branch
    }

    ensure-jira-context

    let content = ticket-to-md (ticket fetch $ticket)
    let url = $"($env.JIRA_URL)/browse/($ticket)"
    let overwrite = if $force { ["--force"] } else { [] }

    (
        $content
        | cue add -t spec --context jira $"tickets/($ticket).md" -f $"url=($url)" ...$overwrite
    )
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

export def "test" [--only-failures, ...args] {
    let result = if $only_failures {
        do { go-task test -- --format json --only-failures ...$args } | complete
    } else {
        do { go-task test -- --format json ...$args } | complete
    }

    let stdout = $result.stdout

    if ($stdout | is-empty) {
        if ($result.stderr | is-not-empty) {
            print -e $result.stderr
        }
        return
    }

    let failed = $stdout | from json | get examples | where $it.status == "failed"

    ($failed | to json) | cue add --type tmp --force rspec-failures.json
}

# TODO: rewrite this in nushell
export alias "pr create" = sb-create-pr
