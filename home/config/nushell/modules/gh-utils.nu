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

export def "repo clone" [
    repo: string
    --subdir(-s): string
] {
    if $subdir != null {
        gh_clone_repo -s $subdir $repo
    } else {
        gh_clone_repo $repo
    }
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
        gh api --paginate --slurp $"repos/($owner)/($repo)/pulls/($pr_num)/reviews"
    } | complete)

    if $reviews_response.exit_code != 0 {
        error make { msg: $reviews_response.stderr }
    }

    let reviews = $reviews_response.stdout | from json | flatten

    if $full {
        # Return full JSON payload
        if $with_comments {
            # Fetch comments for each review
            let reviews_with_comments = $reviews | each {|review| {
                let comments_response = (do {
                    gh api --paginate --slurp $"repos/($owner)/($repo)/pulls/($pr_num)/reviews/($review.id)/comments"
                } | complete)

                let comments = if $comments_response.exit_code == 0 {
                    $comments_response.stdout | from json | flatten
                } else {
                    []
                }

                $review | merge {comments: $comments}
            }}
            $reviews_with_comments | to json
        } else {
            $reviews | to json
        }
    } else {
        # Return filtered JSON optimized for AI agents
        if $with_comments {
            let reviews_with_comments = $reviews | each {|review| {
                let comments_response = (do {
                    gh api --paginate --slurp $"repos/($owner)/($repo)/pulls/($pr_num)/reviews/($review.id)/comments"
                } | complete)

                let comments = if $comments_response.exit_code == 0 {
                    $comments_response.stdout
                    | from json
                    | flatten
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

export def "review comments" [pr_number?: int, --full, --json] {
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
        gh api --paginate --slurp $"repos/($owner)/($repo)/pulls/($pr_num)/comments"
    } | complete)

    if $comments_response.exit_code != 0 {
        error make { msg: $comments_response.stderr }
    }

    if $full {
        # Return full JSON payload with all metadata
        $comments_response.stdout | from json | flatten | to json
    } else {
        # Return filtered JSON optimized for AI agents (default)
        let comments = $comments_response.stdout
        | from json
        | flatten
        | each {|c| {
            id: $c.id
            in_reply_to_id: ($c.in_reply_to_id? | default null)
            author: $c.user.login
            path: $c.path
            body: $c.body
            diff_hunk: $c.diff_hunk
        }}

        if $json {
            $comments | to json
        } else {
            review-comments-to-md $comments
        }
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
        gh api --paginate --slurp $"repos/($owner)/($repo)/issues/($pr_num)/comments"
    } | complete)

    if $comments_response.exit_code != 0 {
        error make { msg: $comments_response.stderr }
    }

    if $full {
        # Return full JSON payload with all metadata
        $comments_response.stdout | from json | flatten | to json
    } else {
        # Return filtered JSON optimized for AI agents (default)
        $comments_response.stdout
        | from json
        | flatten
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
            gh api --paginate --slurp $"repos/($owner)/($repo)/pulls/($pr_number)/reviews/($review_id)/comments"
        } | complete)

        if $comments_response.exit_code != 0 {
            []
        } else {
            $comments_response.stdout | from json | flatten
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
            $review | to json
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

# Post replies to PR review comments from a manifest (YAML or JSON):
#
#   repo: owner/name
#   pr: 123
#   replies:              # reply to existing review comments
#     - comment_id: 456
#       commits: [abc1234, "def5678...0a1b2c3"]   # optional
#       body: |                                  # optional
#         Explanation.
#   comments:             # post new comments on the PR diff
#     - path: src/foo.rs
#       line: 12          # right side by default; side: LEFT for the old one
#       body: |
#
# Each reply needs commits, body, or both. The posted text is the commits
# (one per line, as written), a blank line, then the body. Before posting
# anything it checks:
# - every comment id belongs to the PR; replies go to the thread root;
# - every commit (both ends of a range) prefix-matches exactly one PR
#   commit; one failure aborts the whole run;
# - a reply whose text already exists from you in the thread is skipped.
export def "review comments post" [
    manifest: path
    --dry-run (-n) # Print what would be posted without posting
    --yes (-y)     # Post without asking for confirmation
] {
    let m = open $manifest
    mut errors = []

    let extra = ($m | columns | where $it not-in [repo pr replies comments])
    if not ($extra | is-empty) {
        $errors = $errors | append $"unknown manifest key\(s\): ($extra | str join ', ')"
    }
    for r in ($m.replies? | default []) {
        let extra = ($r | columns | where $it not-in [comment_id commits body])
        if not ($extra | is-empty) {
            $errors = $errors | append $"reply entry has unknown key\(s\): ($extra | str join ', ') \(dropped by GitHub? use comment_id/commits/body\)"
        }
        if ($r.comment_id? | is-empty) {
            $errors = $errors | append "reply entry without comment_id"
        }
    }
    for c in ($m.comments? | default []) {
        let extra = ($c | columns | where $it not-in [path line side body])
        if not ($extra | is-empty) {
            $errors = $errors | append $"comment entry has unknown key\(s\): ($extra | str join ', ')"
        }
        if ($c.path? | is-empty) or ($c.line? | is-empty) {
            $errors = $errors | append $"comment entry missing path or line"
        }
    }
    let repo = $m.repo
    let pr = $m.pr

    let gh_json = {|endpoint|
        let r = (do { gh api --paginate --slurp $endpoint } | complete)
        if $r.exit_code != 0 { error make { msg: $"gh api ($endpoint): ($r.stderr)" } }
        $r.stdout | from json | flatten
    }

    let me_r = (do { gh api user --jq .login } | complete)
    if $me_r.exit_code != 0 { error make { msg: $me_r.stderr } }
    let me = $me_r.stdout | str trim

    let shas = (do $gh_json $"repos/($repo)/pulls/($pr)/commits") | get sha
    # PR commits are oldest-first; the head is the PR's head sha.
    let pr_r = (do { gh api $"repos/($repo)/pulls/($pr)" --jq .head.sha } | complete)
    if $pr_r.exit_code != 0 { error make { msg: $pr_r.stderr } }
    let head = $pr_r.stdout | str trim
    let comments = do $gh_json $"repos/($repo)/pulls/($pr)/comments"

    mut plan = []
    mut new_plan = []
    for r in ($m.replies? | default []) {
        let id = $r.comment_id
        let commits = $r.commits? | default [] | each {|c| $c | into string | str trim } | where $it != ""
        let body = $r.body? | default "" | into string | str trim

        if ($commits | is-empty) and ($body | is-empty) {
            $errors = $errors | append $"comment ($id): needs commits, body, or both"
            continue
        }
        let target = $comments | where id == $id
        if ($target | is-empty) {
            $errors = $errors | append $"comment ($id): not a review comment on PR ($pr)"
            continue
        }
        let root = $target.0.in_reply_to_id? | default $id

        let shas_idx = ($shas | enumerate | rename idx sha)
        for ref in ($commits | each {|c| $c | split row "..." } | flatten | where $it != "") {
            let t = $ref | str trim --char '.' | str downcase
            let hits = $shas_idx | where {|s| $s.sha | str starts-with $t }
            if ($t !~ '^[0-9a-f]{7,40}$') {
                $errors = $errors | append $"comment ($id): '($ref)' is not a commit hash \(7-40 hex chars\)"
            } else if ($hits | length) > 1 {
                $errors = $errors | append $"comment ($id): ($ref) is ambiguous among PR commits"
            } else if ($hits | is-empty) {
                $errors = $errors | append $"comment ($id): ($ref) is not a commit of PR ($pr) \(not pushed, or rebased?\)"
            }
            $hits | each {|h| $h.idx }
        }
        # Range order: PR commits are oldest-first, so index(first) must be below index(last).
        let idxs = ($commits | where {|c| ($c | str contains "...") } | each {|c|
            let ends = ($c | split row "..." | each {|t| $t | str trim --char '.' | str downcase })
            $ends | each {|t| $shas_idx | where {|s| $s.sha | str starts-with $t } | get -o idx | first }
        } | flatten)
        if (($idxs | length) mod 2) == 0 and ($idxs | length) > 0 {
            let pairs = ($idxs | chunks 2)
            for pair in $pairs {
                if $pair.0 >= $pair.1 {
                    $errors = $errors | append $"comment ($id): range is reversed \(older...newer expected\)"
                }
            }
        }

        let text = [($commits | str join "\n") $body] | where $it != "" | str join "\n\n"
        let dup_remote = $comments | any {|c|
            ($c.id == $root or ($c.in_reply_to_id? == $root)) and $c.user.login == $me and ($c.body | str trim) == $text
        }
        if ($plan | any {|p| $p.root == $root and $p.text == $text }) {
            $errors = $errors | append $"comment ($id): duplicate reply \(same thread, same text\) within this manifest"
        }
        $plan = $plan | append {
            comment_id: $id
            root: $root
            author: $target.0.user.login
            path: $target.0.path
            text: $text
            skip: $dup_remote
        }
    }

    for c in ($m.comments? | default []) {
        let body = $c.body? | default "" | into string | str trim
        if ($body | is-empty) {
            $errors = $errors | append $"comment on ($c.path):($c.line): empty body"
            continue
        }
        let dup = ($comments | any {|x| ($x.user.login == $me) and ($x.path == $c.path) and (($x.body | str trim) == $body) and (($x.line? | default ($x.original_line? | default null)) == $c.line) })
        $new_plan = $new_plan | append {
            path: $c.path
            line: $c.line
            side: ($c.side? | default "RIGHT")
            body: $body
            skip: $dup
        }
    }
    let plan = ($plan | append ($new_plan | each {|p| {new: true} | merge $p}))

    for p in $plan {
        let status = if $p.skip { $"(ansi yellow)[skip: already posted](ansi reset)" } else { "" }
        let head = if ($p.new? | default false) {
            $"(ansi cyan)new comment(ansi reset)"
        } else {
            let via = if $p.root != $p.comment_id { $" -> thread ($p.root)" } else { "" }
            $"(ansi cyan)reply(ansi reset) to ($p.comment_id)($via) by (ansi green)($p.author)(ansi reset)"
        }
        print $""
        print $"── ($head) ($status)"
        let loc = if ($p.new? | default false) { $"($p.path):($p.line) ($p.side)" } else { $p.path }
        print $"  (ansi blue)($loc)(ansi reset)"
        let content = if ($p.new? | default false) { $p.body } else { $p.text }
        print ($content | lines | each {|l| $"  ($l)" } | str join "\n")
    }

    if not ($errors | is-empty) {
        error make { msg: ($errors | str join "\n") }
    }

    let todo = $plan | where skip == false
    if $dry_run {
        print $"\nDry run: ($todo | length) to post, ($plan | length) total."
        return
    }
    if not $yes {
        let answer = (input $"Post ($todo | length) of ($plan | length) to ($repo)#($pr)? [y/N] ")
        if ($answer | str downcase | str substring 0..0) != "y" {
            print "Aborted."
            return
        }
    }

    for p in $todo {
        let res = if ($p.new? | default false) {
            do {
                gh api --method POST $"repos/($repo)/pulls/($pr)/comments" -f $"commit_id=($head)" -f $"path=($p.path)" -F $"line=($p.line)" -f $"side=($p.side)" -f $"body=($p.body)" --jq .html_url
            } | complete
        } else {
            do {
                gh api --method POST $"repos/($repo)/pulls/($pr)/comments/($p.root)/replies" -f $"body=($p.text)" --jq .html_url
            } | complete
        }
        if $res.exit_code != 0 {
            error make { msg: $"posting ($p.comment_id? | default $"($p.path):($p.line)") failed: ($res.stderr)" }
        }
        print ($res.stdout | str trim)
    }
}

# TODO:
# - [] display as threads with grouped replies
# - [] fix the diff size, show only the relevant few lines sam as what the github UI shows
def review-comments-to-md [comments: list<record>] {
    $comments
        | each { |it|
            # Extract line number from diff hunk (e.g., @@ -26,11 +26,30 @@)
            let line_info = ($it.diff_hunk | parse -r '@@ -\d+(?:,\d+)? \+(?P<line>\d+)(?:,\d+)? @@')
            let line_suffix = if ($line_info | is-empty) { "" } else { $":($line_info.0.line)" }

            [
                $"## `($it.path)($line_suffix)` by @($it.author)",
                "",
                $it.body,
                "",
                "```diff",
                $it.diff_hunk,
                "```",
                ""
            ] | str join "\n"
        }
        | str join "\n---\n\n"
}
