#!/usr/bin/env zsh

gh_pr_create() {
    title=$1
    body=$2
    gh pr create --title "$title" --body "$body" "${@:3}"
}

gh_prs() {
    if [ $# -eq 0 ]; then
        gh f -p
    else
        gh pr checkout "$1"
    fi

    set_pr_base_from_gh
}

alias prs="gh_prs"
alias prw="gh pr view --web"
alias prc="gh_pr_create"
alias pre="gh_pr_create"
