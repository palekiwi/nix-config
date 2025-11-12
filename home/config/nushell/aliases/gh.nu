def prc [body:string = "", title:string = "", ...rest] {
    gh pr create --title $title --body $body $rest
}

def gh_pr_link [] {
    let repo_url = gh repo view --json url --jq '.url'

    echo $"($repo_url)/pull/(get_pr_number)"
}

def gprc [...args] {
    gh_pr_from_branch_name $args
    set_pr_info
}

alias p = gh_prs
alias pgrev = gh pr comment --body "/gemini review"
alias pitr = gh pr comment --body 'ITR'
alias plgtm = gh pr review --approve --body 'LGTM'
alias pre = gh_pr_create
alias prl = gh_pr_link
alias prs = gh_prs
alias prw = gh pr view --web
