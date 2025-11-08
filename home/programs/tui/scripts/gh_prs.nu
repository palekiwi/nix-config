def build_pr_tree [prs: list] {
    # Get the default branch
    let default_branch_result = (do { gh repo view --json defaultBranchRef } | complete)
    let default_branch = if $default_branch_result.exit_code == 0 {
        ($default_branch_result.stdout | from json).defaultBranchRef.name
    } else {
        "master"
    }

    # Build a map of branch -> PR for quick lookup
    let branch_to_pr = ($prs | reduce -f {} { |pr, acc|
        $acc | upsert $pr.headRefName $pr
    })

    # Find root PRs (those that target the default branch or non-PR branches)
    let root_prs = ($prs | where { |pr|
        $pr.baseRefName == $default_branch or ($branch_to_pr | get -i $pr.baseRefName) == null
    })

    # Recursive function to build tree structure
    def build_subtree [pr: record, branch_map: record, visited: list, depth: int] {
        if ($pr.headRefName in $visited) {
            return []
        }

        let new_visited = ($visited | append $pr.headRefName)
        let children = ($branch_map | columns | where { |branch|
            ($branch_map | get $branch).baseRefName == $pr.headRefName
        } | each { |branch|
            build_subtree ($branch_map | get $branch) $branch_map $new_visited ($depth + 1)
        } | flatten)

        [{pr: $pr, depth: $depth, children: $children}]
    }

    # Build the full tree
    let tree = ($root_prs | each { |pr|
        build_subtree $pr $branch_to_pr [] 0
    } | flatten)

    $tree
}

def format_tree_entry [entry: record] {
    let pr = $entry.pr
    let depth = $entry.depth

    # Create indentation
    let indent = if $depth == 0 { "" } else {
        (0..($depth - 1) | each { "│ " } | str join) + "├─"
    }

    let colors = {
        blue: "\u{001b}[34m"
        gray: "\u{001b}[90m",
        green: "\u{001b}[32m",
        purple: "\u{001b}[35m"
        reset: "\u{001b}[0m",
        tree_color: "\u{001b}[37m",
    }

    # Format labels
    let label_names = ($pr.labels | each { |l| $l.name } | str join ", ")
    let labels_str = $"($colors.purple)[($label_names)]($colors.reset)"

    let unique_reviewers = ($pr | get reviews | each { |r| $r.author.login } | uniq | where $it != "gemini-code-assist" | where $it != $pr.author.login)
    let approvals = ($pr | get reviews | where { |r| $r.state == "APPROVED" } | each { |r| $r.author.login } | uniq | length)
    let reviewer_count = ($unique_reviewers | length)
    let reviews_str = if $reviewer_count > 0 {
        $" ($colors.tree_color)($approvals)/($reviewer_count)($colors.reset)"
    } else {
        ""
    }

    let pr_color = if $pr.isDraft { $colors.tree_color } else { $colors.green }

    $"($colors.tree_color)($indent)($colors.reset)($pr_color)($pr.number)($colors.reset): ($pr.title) ($labels_str)($reviews_str) ($colors.gray)\(($colors.green)($pr.headRefName)($colors.gray)\) - @($pr.author.login)($colors.reset)"
}

def flatten_tree [tree: list] {
    def flatten_entry [entry: record] {
        let current = [$entry]
        let children = ($entry.children | each { |child| flatten_entry $child } | flatten)
        $current | append $children
    }

    $tree | each { |entry| flatten_entry $entry } | flatten
}

def filter_prs [
    prs: list
    draft?: bool
    authors?: string
    exclude_authors?: string
    labels?: string
    exclude_labels?: string
    lgtm?: bool
    exclude_lgtm?: bool
    reviewed?: bool
    exclude_reviewed?: bool
] {
    let prs = if ($draft | default false) {
        $prs
    } else {
        $prs | where { |pr| $pr.isDraft == false }
    }

    let authors_list = if ($authors | is-not-empty) {
        $authors | split row "," | each { |a| $a | str downcase }
    } else {
        []
    }

    let exclude_authors_list = if ($exclude_authors | is-not-empty) {
        $exclude_authors | split row "," | each { |a| $a | str downcase }
    } else {
        []
    }

    let prs = if ($authors_list | is-not-empty) {
        $prs | where { |pr| ($pr.author.login | str downcase) in $authors_list }
    } else {
        $prs
    }

    let prs = if ($exclude_authors_list | is-not-empty) {
        $prs | where { |pr| ($pr.author.login | str downcase) not-in $exclude_authors_list }
    } else {
        $prs
    }

    let labels_list = if ($labels | is-not-empty) {
        $labels | split row "," | each { |l| $l | str downcase }
    } else {
        []
    }

    let exclude_labels_list = if ($exclude_labels | is-not-empty) {
        $exclude_labels | split row "," | each { |l| $l | str downcase }
    } else {
        []
    }

    let prs = if ($labels_list | is-not-empty) {
        $prs | where { |pr|
            ($pr.labels | any { |l| ($l.name | str downcase) in $labels_list })
        }
    } else {
        $prs
    }

    let prs = if ($exclude_labels_list | is-not-empty) {
        $prs | where { |pr|
            ($pr.labels | all { |l| ($l.name | str downcase) not-in $exclude_labels_list })
        }
    } else {
        $prs
    }

    let prs = if ($lgtm | default false) {
        $prs | where { |pr|
            $pr.reviews | any { |r| $r.state == "APPROVED" and $r.author.login == "palekiwi" }
        }
    } else {
        $prs
    }

    let prs = if ($exclude_lgtm | default false) {
        $prs | where { |pr|
            not ($pr.reviews | any { |r| $r.state == "APPROVED" and $r.author.login == "palekiwi" })
        }
    } else {
        $prs
    }

    let prs = if ($reviewed | default false) {
        $prs | where { |pr|
            $pr.author.login != "palekiwi" and ($pr.reviews | any { |r| $r.author.login == "palekiwi" })
        }
    } else {
        $prs
    }

    let prs = if ($exclude_reviewed | default false) {
        $prs | where { |pr|
            $pr.author.login == "palekiwi" or not ($pr.reviews | any { |r| $r.author.login == "palekiwi" })
        }
    } else {
        $prs
    }

    $prs
}

def format_table [prs: list] {
    $prs | each { |pr|
        let unique_reviewers = ($pr.reviews | each { |r| $r.author.login } | uniq | where $it != "gemini-code-assist" | where $it != $pr.author.login)
        let approvals = ($pr.reviews | where { |r| $r.state == "APPROVED" } | each { |r| $r.author.login } | uniq | length)
        let reviewer_count = ($unique_reviewers | length)
        let number_color = if $pr.isDraft { "white" } else { "green" }
        let $reviews_str = if $reviewer_count > 0 { $"($approvals)/($reviewer_count)" } else { "" }

        {
            index: $"((if $pr.isDraft { ansi white } else { ansi green }))($pr.number)(ansi reset)"
            title: $"(ansi default)($pr.title)(ansi reset)"
            labels: $"(ansi purple)($pr.labels | each { |l| $l.name } | str join ', ')(ansi reset)"
            cr: $"(ansi teal)($reviews_str)(ansi reset)"
            branch: $"(ansi green)($pr.headRefName)(ansi reset)"
            base: $pr.baseRefName
            author: $"(ansi blue)($pr.author.login)(ansi reset)"
        }
    }
}

def main [
    pr_string?: string
    --authors(-a): string
    --draft(-d)
    --exclude-authors(-A): string
    --exclude-labels(-L): string
    --exclude-lgtm(-G)
    --exclude-reviewed(-R)
    --labels(-l): string
    --lgtm(-g)
    --print
    --reviewed(-r)
    --tree(-t)
] {
    # Check if we're in a git repository
    if (do { git rev-parse --git-dir } | complete).exit_code != 0 {
        print "Error: Not in a git repository"
        exit 1
    }

    # If an argument is provided, checkout that PR directly
    if ($pr_string | is-not-empty) {
        let pr_info = (do { gh pr view $pr_string --json number,baseRefName } | complete)

        if $pr_info.exit_code != 0 {
            print $"Error: Could not find PR: ($pr_string)"
            exit 1
        }

        let pr_data = ($pr_info.stdout | from json)
        let pr_number = $pr_data.number
        let base_branch = $pr_data.baseRefName

        let checkout_result = (do { gh pr checkout $pr_number } | complete)
        if $checkout_result.exit_code == 0 {
            print $"Successfully checked out PR #($pr_number)"
        } else {
            print $"Failed to checkout PR #($pr_number)"
            exit 1
        }

        return
    }

    # Original interactive flow if no argument provided
    let pr_list_result = (do {
        gh pr list --json number,title,author,headRefName,baseRefName,labels,isDraft,reviews
    } | complete)

    if $pr_list_result.exit_code != 0 {
        print "Error: Failed to get PR list"
        exit 1
    }

    let prs = ($pr_list_result.stdout | from json)

    let prs = (filter_prs $prs $draft $authors $exclude_authors $labels $exclude_labels $lgtm $exclude_lgtm $reviewed $exclude_reviewed)

    if ($prs | is-empty) {
        print "No open PRs found"
        return
    }

    let formatted_output = if $tree {
        let tree = (build_pr_tree $prs)
        let flat_tree = (flatten_tree $tree)
        ($flat_tree | each { |entry| format_tree_entry $entry } | str join "\n")
    } else {
        let table_data = (format_table $prs)
        ($table_data | table -e --theme none | to text | lines | skip 1 | to text)
    }

    if $print {
        print $formatted_output
        return
    }

    let selected = ($formatted_output | fzf --ansi --border --prompt="Select PR to checkout: " --preview-window=top:50% --preview="echo {} | grep -o '[0-9]*:' | sed 's/://' | xargs gh pr view" --bind="ctrl-h:execute-silent(echo {} | grep -o '[0-9]*:' | sed 's/://' | xclip -selection clipboard)" --bind="ctrl-y:execute-silent(echo {} | grep -o '[0-9]*:' | sed 's/://' | xargs gh pr view --web)" --tac)

    if ($selected | is-empty) {
        print "No PR selected"
        return
    }

    let pr_number = ($selected | parse --regex '(\d+)' | get capture0.0 | into int)

    let checkout_result = (do { gh pr checkout $pr_number } | complete)
    if $checkout_result.exit_code == 0 {
        print $"Successfully checked out PR #($pr_number)"
    } else {
        print $"Failed to checkout PR #($pr_number)"
        exit 1
    }
}
