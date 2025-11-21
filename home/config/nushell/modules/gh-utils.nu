export def "pr body" [pr_number?: int, --save] {
    let pr_number = $pr_number | default ""
    let response = (do { gh pr view ($pr_number) --json body } | complete)
    if $response.exit_code != 0 {
        error make { msg: $response.stderr }
    }

    let content = $response.stdout | from json | get body

    if $save {
        let dir = $".agents/(git branch --show-current)"
        let filename = if ($pr_number | is-empty) { "pr-body.md" } else { $"pr-($pr_number)-body.md"}
        let dest = $"($dir)/($filename)"

        mkdir $dir
        $content | save -f $dest

        $dest
    } else {
        $content
    }
}

export def "run list" [
    --commit(-c): string
    --workflow(-w): string
] {
    let $commit = if $commit != null { $commit } else {git rev-parse HEAD }
    let workflow_flag = if $workflow != null { ["-w" $workflow] } else { [] }

    (
        gh run list
            --json workflowName,databaseId,displayTitle,status,conclusion,createdAt
            -c $commit
            ...$workflow_flag
    )
    | from json
    | into datetime createdAt
    | rename result created id title status name
}
