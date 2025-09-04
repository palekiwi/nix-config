#!/usr/bin/env zsh

source ~/.config/zsh/aliases.d/gh/gh_prs.zsh

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

gh_clone() {
    $HOME/.config/zsh/aliases.d/gh/clone_repo.zsh $@
}

gh_pr_link() {
    PR_NUMBER=$(get_pr_number)
    echo "https://github.com/ygt/spabreaks/pull/${PR_NUMBER}" # TODO: get the real GH remote
}

alias p="gh_prs"
alias prs="gh_prs"
alias prl="gh_pr_link"
alias prw="gh pr view --web"
alias prc="gh_pr_create"
alias prcy="gh_pr_create_ygt"
alias pre="gh_pr_create"
alias pitr="gh pr comment --body 'ITR'"
alias plgtm="gh pr review --approve --body 'LGTM'"
