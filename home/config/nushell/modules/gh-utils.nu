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
    # TODO allow listing for all commits
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

export def "pr reviews" [pr_number?: int, --full, --with-comments] {
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

    # Fetch all reviews for the PR
    let reviews_response = (do {
        gh api $"repos/($owner)/($repo)/pulls/($pr_num)/reviews"
    } | complete)

    if $reviews_response.exit_code != 0 {
        error make { msg: $reviews_response.stderr }
    }

    let reviews = $reviews_response.stdout | from json

    if $full {
        # Return full JSON payload
        if $with_comments {
            # Fetch comments for each review
            let reviews_with_comments = $reviews | each {|review| {
                let comments_response = (do {
                    gh api $"repos/($owner)/($repo)/pulls/($pr_num)/reviews/($review.id)/comments"
                } | complete)

                let comments = if $comments_response.exit_code == 0 {
                    $comments_response.stdout | from json
                } else {
                    []
                }

                $review | merge {comments: $comments}
            }}
            $reviews_with_comments | to json
        } else {
            $reviews_response.stdout
        }
    } else {
        # Return filtered JSON optimized for AI agents
        if $with_comments {
            let reviews_with_comments = $reviews | each {|review| {
                let comments_response = (do {
                    gh api $"repos/($owner)/($repo)/pulls/($pr_num)/reviews/($review.id)/comments"
                } | complete)

                let comments = if $comments_response.exit_code == 0 {
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
                } else {
                    []
                }

                {
                    id: $review.id
                    author: $review.user.login
                    state: $review.state
                    body: $review.body
                    submitted_at: $review.submitted_at
                    comments: $comments
                }
            }}
            $reviews_with_comments | to json
        } else {
            $reviews 
            | each {|r| {
                id: $r.id
                author: $r.user.login
                state: $r.state
                body: $r.body
                submitted_at: $r.submitted_at
            }}
            | to json
        }
    }
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

export def "pr comments" [pr_number?: int, --full] {
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

    # Fetch PR discussion comments using the issues API endpoint
    let comments_response = (do {
        gh api $"repos/($owner)/($repo)/issues/($pr_num)/comments"
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
            body: $c.body
            created_at: $c.created_at
            updated_at: $c.updated_at
        }}
        | to json
    }
}

export def "pr comment" [
    --id: int
    --url: string
    --full
] {
    # Determine comment ID from either --id or --url
    let comment_id = if $id != null {
        $id
    } else if $url != null {
        # Parse GitHub PR comment URL
        # Example: https://github.com/spabreaks/terraform/pull/95#issuecomment-2587332885
        let parsed = ($url | parse --regex 'issuecomment-(?P<id>\d+)')
        if ($parsed | is-empty) {
            error make { msg: "Could not parse comment ID from URL" }
        }
        $parsed | get 0.id | into int
    } else {
        error make { msg: "Must provide either --id or --url" }
    }

    # Get current repo info
    let repo_info = (do { gh repo view --json owner,name } | complete)
    if $repo_info.exit_code != 0 {
        error make { msg: $repo_info.stderr }
    }

    let repo_data = $repo_info.stdout | from json
    let owner = $repo_data.owner.login
    let repo = $repo_data.name

    # Fetch single PR comment by ID using the issues API endpoint
    let comment_response = (do {
        gh api $"repos/($owner)/($repo)/issues/comments/($comment_id)"
    } | complete)

    if $comment_response.exit_code != 0 {
        error make { msg: $comment_response.stderr }
    }

    if $full {
        # Return full JSON payload
        $comment_response.stdout
    } else {
        # Return filtered JSON
        let c = ($comment_response.stdout | from json)
        {
            id: $c.id
            in_reply_to_id: ($c.in_reply_to_id? | default null)
            author: $c.user.login
            body: $c.body
            created_at: $c.created_at
            updated_at: $c.updated_at
        } | to json
    }
}

export def "review comment" [
    --id: int
    --url: string
    --full
] {
    # Determine comment ID from either --id or --url
    let comment_id = if $id != null {
        $id
    } else if $url != null {
        # Parse GitHub PR comment URL
        # Example: https://github.com/spabreaks/terraform/pull/95#discussion_r2587332885
        let parsed = ($url | parse --regex 'discussion_r(?P<id>\d+)')
        if ($parsed | is-empty) {
            error make { msg: "Could not parse comment ID from URL" }
        }
        $parsed | get 0.id | into int
    } else {
        error make { msg: "Must provide either --id or --url" }
    }

    # Get current repo info
    let repo_info = (do { gh repo view --json owner,name } | complete)
    if $repo_info.exit_code != 0 {
        error make { msg: $repo_info.stderr }
    }

    let repo_data = $repo_info.stdout | from json
    let owner = $repo_data.owner.login
    let repo = $repo_data.name

    # Fetch single review comment by ID
    let comment_response = (do {
        gh api $"repos/($owner)/($repo)/pulls/comments/($comment_id)"
    } | complete)

    if $comment_response.exit_code != 0 {
        error make { msg: $comment_response.stderr }
    }

    if $full {
        # Return full JSON payload
        $comment_response.stdout
    } else {
        # Return filtered JSON
        let c = ($comment_response.stdout | from json)
        {
            id: $c.id
            in_reply_to_id: ($c.in_reply_to_id? | default null)
            author: $c.user.login
            path: $c.path
            body: $c.body
            diff_hunk: $c.diff_hunk
        } | to json
    }
}

export def "pr review" [
    --id: int
    --url: string
    --full
    --with-comments
] {
    # Parse review ID and PR number from URL or use provided ID
    let review_data = if $id != null {
        # If only ID is provided, we need to get the PR number from current context
        let pr_response = (do { gh pr view --json number } | complete)
        if $pr_response.exit_code != 0 {
            error make { msg: $pr_response.stderr }
        }
        let pr_num = ($pr_response.stdout | from json | get number)
        {review_id: $id, pr_number: $pr_num}
    } else if $url != null {
        # Parse GitHub PR review URL
        # Example: https://github.com/spabreaks/spabreaks/pull/10230#pullrequestreview-3652943235
        let parsed = ($url | parse --regex 'pull/(?P<pr>\d+)#pullrequestreview-(?P<id>\d+)')
        if ($parsed | is-empty) {
            error make { msg: "Could not parse review ID from URL. Expected format: .../pull/{number}#pullrequestreview-{id}" }
        }
        let parsed_data = $parsed | get 0
        {review_id: ($parsed_data.id | into int), pr_number: ($parsed_data.pr | into int)}
    } else {
        error make { msg: "Must provide either --id or --url" }
    }

    let review_id = $review_data.review_id
    let pr_number = $review_data.pr_number

    # Get current repo info
    let repo_info = (do { gh repo view --json owner,name } | complete)
    if $repo_info.exit_code != 0 {
        error make { msg: $repo_info.stderr }
    }

    let repo_data = $repo_info.stdout | from json
    let owner = $repo_data.owner.login
    let repo = $repo_data.name

    # Fetch the review
    let review_response = (do {
        gh api $"repos/($owner)/($repo)/pulls/($pr_number)/reviews/($review_id)"
    } | complete)

    if $review_response.exit_code != 0 {
        error make { msg: $review_response.stderr }
    }

    let review = ($review_response.stdout | from json)

    # Optionally fetch associated comments
    let comments = if $with_comments {
        let comments_response = (do {
            gh api $"repos/($owner)/($repo)/pulls/($pr_number)/reviews/($review_id)/comments"
        } | complete)

        if $comments_response.exit_code != 0 {
            []
        } else {
            $comments_response.stdout | from json
        }
    } else {
        []
    }

    if $full {
        # Return full JSON payload
        if $with_comments {
            {
                review: $review
                comments: $comments
            } | to json
        } else {
            $review_response.stdout
        }
    } else {
        # Return filtered JSON
        let filtered_review = {
            id: $review.id
            author: $review.user.login
            state: $review.state
            body: $review.body
            submitted_at: $review.submitted_at
        }

        if $with_comments {
            let filtered_comments = $comments | each {|c| {
                id: $c.id
                in_reply_to_id: ($c.in_reply_to_id? | default null)
                author: $c.user.login
                path: $c.path
                body: $c.body
                diff_hunk: $c.diff_hunk
            }}

            {
                review: $filtered_review
                comments: $filtered_comments
            } | to json
        } else {
            $filtered_review | to json
        }
    }
}
