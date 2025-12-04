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

export def "repo clone" [repo: string] {
    gh_clone_repo $repo
}

export def "review comments" [pr_number?: int, --full] {
    let pr_number = $pr_number | default ""
    
    # Get PR data to extract repository info
    let pr_response = (do { gh pr view ($pr_number) --json number,headRepository,headRepositoryOwner } | complete)
    if $pr_response.exit_code != 0 {
        error make { msg: $pr_response.stderr }
    }

    let pr_data = $pr_response.stdout | from json
    let owner = $pr_data.headRepositoryOwner.login
    let repo = $pr_data.headRepository.name
    let pr_num = $pr_data.number
    
    # Fetch review comments directly using the correct API endpoint
    let comments_response = (do {
        gh api $"repos/($owner)/($repo)/pulls/($pr_num)/comments"
    } | complete)
    
    if $comments_response.exit_code != 0 {
        error make { msg: $comments_response.stderr }
    }

    if $full {
        # Return full JSON payload with all metadata
        $comments_response.stdout
    } else {
        # Return filtered JSON optimized for AI agents (default)
        $comments_response.stdout 
        | from json 
        | each {|c| {
            id: $c.id
            in_reply_to_id: ($c.in_reply_to_id? | default null)
            author: $c.user.login
            path: $c.path
            body: $c.body
            diff_hunk: $c.diff_hunk
        }}
        | to json
    }
}
