#!/usr/bin/env nu

def set_pr_env [pr_num: int, base_ref?: string] {
    if ($base_ref | is-empty) {
        $env.GIT_BASE = null
        $env.GH_PR_NUMBER = null
    } else {
        $env.GIT_BASE = $base_ref
        $env.GH_PR_NUMBER = $pr_num
    }
}

def main [pr_string?: string] {
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
            # set_pr_env $pr_number $base_branch
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

    # Format PR list for display
    let formatted_prs = ($prs | each { |pr|
        let labels_str = if ($pr.labels | is-not-empty) {
            let label_names = ($pr.labels | each { |l| $l.name } | str join ", ")
            $" \u{001b}[35m[($label_names)]\u{001b}[0m"
        } else {
            ""
        }

        let green = "\u{001b}[32m"
        let reset = "\u{001b}[0m" 
        let gray = "\u{001b}[90m"
        let cyan = "\u{001b}[36m"
        
        $"($green)($pr.number)($reset): ($pr.title)($labels_str) ($gray)\(($green)($pr.headRefName)($gray) → ($cyan)($pr.baseRefName)($gray)\)($reset)"
    })

    # Use fzf for interactive selection
    let selected = ($formatted_prs | str join "\n" | fzf --ansi --border --prompt="Select PR to checkout: " --preview-window=top:50% --preview="echo {} | grep -o '^[0-9]*' | xargs gh pr view")

    if ($selected | is-empty) {
        print "No PR selected"
        return
    }

    # Extract PR number from selection
    let pr_number = ($selected | parse --regex '^(\d+):' | get capture0.0 | into int)
    let base_branch = ($selected | parse --regex ' → ([^)]+)\)' | get capture0.0)

    let checkout_result = (do { gh pr checkout $pr_number } | complete)
    if $checkout_result.exit_code == 0 {
        print $"Successfully checked out PR #($pr_number)"
        # set_pr_env $pr_number $base_branch
    } else {
        print $"Failed to checkout PR #($pr_number)"
        exit 1
    }
}
