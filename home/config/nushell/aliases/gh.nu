def prc [body:string = "", title:string = "", ...rest] {
    gh pr create --title $title --body $body $rest
}

def gh_pr_link [] {
    let repo_url = gh repo view --json url --jq '.url'

    echo $"($repo_url)/pull/(get_pr_number)"
}

def gprc [...args] {
    gh_pr_from_branch_name $args
    git-pr-sync
}

def pitr [pr?: int] {
    let target = if $pr == null { [] } else { [$pr] }
    gh pr edit ...$target --add-reviewer palekiwi
    gh pr comment ...$target --body 'ITR'
}

def pgrev [pr?: int] {
    let target = if $pr == null { [] } else { [$pr] }
    gh pr comment ...$target --body "/gemini review"
}

alias p = gh_prs
alias pp = gh_prs -a palekiwi
alias pP = gh_prs -A palekiwi
alias plgtm = gh pr review --approve --body 'LGTM'
alias pre = gh_pr_create
alias prl = gh_pr_link
alias prs = gh_prs
alias prw = gh pr view --web
