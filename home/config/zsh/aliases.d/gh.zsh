#!/usr/bin/env zsh

gh_pr_create() {
    title=$1
    body=$2
    gh pr create --title "$title" --body "$body" "${@:3}"
}

pr_title_from_branch() {
    local ticket_number="$1"
    local remaining="$2"

    local spaced="${remaining//-/ }"

    # Capitalize first letter
    local first_char=$(echo "${spaced:0:1}" | tr '[:lower:]' '[:upper:]')
    local rest="${spaced:1}"

    local ticket_name="${first_char}${rest}"

    echo "SB-$ticket_number | $ticket_name"
}

gh_pr_create_ygt() {
    local branch_name=$(git branch --show-current)
    local ticket_number=$(echo "${branch_name}" | grep -o "^[0-9]\+")
    #
    if [ -z "$ticket_number" ]; then
        echo "Error: Branch name does not start with a number"
        return 1
    fi

    local ticket_number=$(echo "${branch_name}" | grep -o "^[0-9]\+")

    if [ -z "$ticket_number" ]; then
        echo "Error: Branch name does not start with a number"
        return 1
    fi

    # Remove the ticket number and first hyphen
    local remaining="${branch_name#${ticket_number}-}"

    local title=$(pr_title_from_branch_name $ticket_number $remaining)
    local body="[SB-${ticket_number}]"

    gh pr create --title "$title" --body "$body" $@
}

gh_prs() {
    if ! git rev-parse --git-dir &> /dev/null; then
        echo "Error: Not in a git repository"
        exit 1
    fi

    pr_list=$(gh pr list --json number,title,author,headRefName,baseRefName --template $'{{range .}}\033[32m{{.number}}\033[0m: {{.title}} \033[90m({{.baseRefName}} ← {{.headRefName}})\033[0m\n{{end}}')

    if [[ -z "$pr_list" ]]; then
        echo "No open PRs found"
        exit 0
    fi

    selected=$(echo "$pr_list" | fzf --ansi --border \
        --prompt="Select PR to checkout: " \
        --preview-window=top:50% \
        --preview="echo {} | grep -o '^[0-9]*' | xargs gh pr view")

    if [[ -z "$selected" ]]; then
        echo "No PR selected"
        exit 0
    fi

    pr_number=$(echo "$selected" | grep -o '^[0-9]*')

    # Parse base branch from the selected line (between parentheses, before the arrow)
    base_branch=$(echo "$selected" | sed -n 's/.*(\([^←]*\) ← .*/\1/p' | xargs)

    if gh pr checkout "$pr_number"; then
        echo "Successfully checked out PR #$pr_number"
    else
        echo "Failed to checkout PR #$pr_number"
        exit 1
    fi

    # Set environment variables
    if [ -z "$base_branch" ]; then
        unset GIT_BASE 2>/dev/null || true
        unset GH_PR_NUMBER 2>/dev/null || true
    else
        export GIT_BASE="$base_branch"
        export GH_PR_NUMBER="$pr_number"
    fi
}

alias prs="gh_prs"
alias prw="gh pr view --web"
alias prc="gh_pr_create"
alias prcy="gh_pr_create_ygt"
alias pre="gh_pr_create"
