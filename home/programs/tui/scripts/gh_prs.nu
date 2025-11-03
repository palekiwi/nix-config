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

    # Format labels
    let labels_str = if ($pr.labels | is-not-empty) {
        let label_names = ($pr.labels | each { |l| $l.name } | str join ", ")
        $" \u{001b}[35m[($label_names)]\u{001b}[0m"
    } else {
        ""
    }

    let green = "\u{001b}[32m"
    let reset = "\u{001b}[0m"
    let gray = "\u{001b}[90m"
    let tree_color = "\u{001b}[37m"

    $"($tree_color)($indent)($reset)($green)($pr.number)($reset): ($pr.title)($labels_str) ($gray)\(($green)($pr.headRefName)($gray)\)($reset)"
}

def flatten_tree [tree: list] {
    def flatten_entry [entry: record] {
        let current = [$entry]
        let children = ($entry.children | each { |child| flatten_entry $child } | flatten)
        $current | append $children
    }

    $tree | each { |entry| flatten_entry $entry } | flatten
}

def main [--print, pr_string?: string] {
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
        gh pr list --json number,title,author,headRefName,baseRefName,labels
    } | complete)

    if $pr_list_result.exit_code != 0 {
        print "Error: Failed to get PR list"
        exit 1
    }

    let prs = ($pr_list_result.stdout | from json)

    if ($prs | is-empty) {
        print "No open PRs found"
        return
    }

    # Build and format tree
    let tree = (build_pr_tree $prs)
    let flat_tree = (flatten_tree $tree)
    let formatted_prs = ($flat_tree | each { |entry| format_tree_entry $entry })

    # If --print flag is set, output tree to stdout and exit
    if $print {
        print ($formatted_prs | str join "\n")
        return
    }

    # Use fzf for interactive selection
    let selected = ($formatted_prs | str join "\n" | fzf --ansi --border --prompt="Select PR to checkout: " --preview-window=top:50% --preview="echo {} | grep -o '[0-9]*:' | sed 's/://' | xargs gh pr view" --bind="ctrl-h:execute-silent(echo {} | grep -o '[0-9]*:' | sed 's/://' | xclip -selection clipboard)" --bind="ctrl-y:execute-silent(echo {} | grep -o '[0-9]*:' | sed 's/://' | xargs gh pr view --web)" --tac)

    if ($selected | is-empty) {
        print "No PR selected"
        return
    }

    # Extract PR number from selection (handle tree prefixes)
    let pr_number = ($selected | parse --regex '(\d+):' | get capture0.0 | into int)

    let checkout_result = (do { gh pr checkout $pr_number } | complete)
    if $checkout_result.exit_code == 0 {
        print $"Successfully checked out PR #($pr_number)"
    } else {
        print $"Failed to checkout PR #($pr_number)"
        exit 1
    }
}
