#!/usr/bin/env zsh

gh_prs(){
    _set_pr_env() {
        local pr_num="$1"
        local base_ref="$2"

        if [ -z "$base_ref" ]; then
            unset GIT_BASE 2>/dev/null || true
            unset GH_PR_NUMBER 2>/dev/null || true
        else
            export GIT_BASE="$base_ref"
            export GH_PR_NUMBER="$pr_num"
        fi
    }

    # If an argument is provided, checkout that PR directly
    if [[ $# -gt 0 ]]; then
        pr_string="$1"

        if ! git rev-parse --git-dir &> /dev/null; then
            echo "Error: Not in a git repository"
            return 1
        fi

        pr_info=$(gh pr view "$pr_string" --json number,baseRefName 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            echo "Error: Could not find PR: $pr_string"
            return 1
        fi

        pr_number=$(echo "$pr_info" | jq -r '.number')
        base_branch=$(echo "$pr_info" | jq -r '.baseRefName')

        if gh pr checkout "$pr_number"; then
            echo "Successfully checked out PR #$pr_number"
            # _set_pr_env "$pr_number" "$base_branch"
        else
            echo "Failed to checkout PR #$pr_number"
            return 1
        fi

        return 0
    fi

    # Original interactive flow if no argument provided
    if ! git rev-parse --git-dir &> /dev/null; then
        echo "Error: Not in a git repository"
        return 1
    fi

    pr_list=$(gh pr list --json number,title,author,headRefName,baseRefName,labels --template $'{{range .}}\033[32m{{.number}}\033[0m: {{.title}}{{if .labels}} \033[35m[{{range $i, $label := .labels}}{{if $i}}, {{end}}{{$label.name}}{{end}}]\033[0m{{end}} \033[90m(\033[32m{{.headRefName}}\033[90m → \033[90m{{.baseRefName}}\033[90m)\033[0m\n{{end}}')

    if [[ -z "$pr_list" ]]; then
        echo "No open PRs found"
        return 0
    fi

    selected=$(echo "$pr_list" | fzf --ansi --border \
        --prompt="Select PR to checkout: " \
        --preview-window=top:50% \
        --preview="echo {} | grep -o '^[0-9]*' | xargs gh pr view")

    if [[ -z "$selected" ]]; then
        echo "No PR selected"
        return 0
    fi

    pr_number=$(echo "$selected" | grep -o '^[0-9]*')
    base_branch=$(echo "$selected" | sed -n 's/.* → \([^)]*\).*/\1/p' | xargs)

    if gh pr checkout "$pr_number"; then
        echo "Successfully checked out PR #$pr_number"
        # _set_pr_env "$pr_number" "$base_branch"
    else
        echo "Failed to checkout PR #$pr_number"
        return 1
    fi
}
