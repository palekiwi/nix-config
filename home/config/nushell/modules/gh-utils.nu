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
    --status(-s): list<string>
    --workflow(-w): string
] {
    let $commit = if $commit != null { $commit } else {git rev-parse HEAD }
    let status_flag = if ($status | is-empty) { [] } else { $status | each {|it| ["-s" $it] } | flatten }
    let workflow_flag = if $workflow != null { ["-w" $workflow] } else { [] }

    let response = (
        gh run list
            --json workflowName,databaseId,displayTitle,status,conclusion,createdAt
            -c $commit
            ...$status_flag
            ...$workflow_flag
    )

    if ($response | str trim | is-empty) {
        []
    } else {
        $response
        | from json
        | into datetime createdAt
        | rename result created id title status name
    }
}

export def "run view" [run_id: int, --log, --save] {
    if $log {
        let log = gh run view $run_id --log

        if not $save {
            $log
        } else {
            let run_info = gh run view $run_id --json=workflowName,headSha,headBranch | from json

            let branch = $run_info | get headBranch
            let commit = $run_info | get headSha | str substring 0..7
            let name = $run_info | get workflowName

            let dir = $".agents/($branch)/($commit)/runs"
            let dest = $"($dir)/($run_id)_($name | str downcase | str replace --all ' ' '-').log"

            mkdir $dir

            $log | save -f $dest

            print $"Run '($name)' with id '($run_id)' saved to:"

            $dest
        }
    } else {
        gh run view $run_id --json=workflowName,databaseId,displayTitle,status,conclusion,createdAt,url
        | from json
    }
}
