export def git_switch_create_variant [variant: string] {
    git switch -c $"(git branch --show-current)--($variant)"
}

export def git_switch_create_wip [] {
    git switch -c $"(git branch --show-current)--wip-palekiwi"
}

export def git_switch_variant [variant: string] {
    git switch $"(git branch --show-current)--($variant)"
}

export def git_switch_wip [] {
    git switch $"(git branch --show-current)--wip-palekiwi"
}

export def git_merge_variant [variant: string] {
    git merge $"(git branch --show-current)--($variant)"
}

export def git_branch_delete_variant [variant: string] {
    git branch -d $"(git branch --show-current)--($variant)"
}

export def git_fetch_base [] {
    let base_branch = (get_pr_base)
    git fetch origin
    git fetch origin $"($base_branch):($base_branch)"
}

export def git_fetch_master [] {
    let branch = (get_master_branch_name)
    git fetch origin
    git fetch origin $"($branch):($branch)"
}

export def gac [] {
    git add .
    git commit
}

export def gacm [message: string] {
    git add .
    git commit -m $message
}
export alias gar = git_add_remote
export alias gca = git commit --amend
export alias gcir = git_create_init_repo
export alias gcl = git_clone_repo
export alias gclp = git_clone_repo_palekiwi
export alias gclr = git_clone_rpi
export alias gcr = git_create_repo
export alias glog = git log
export alias gpa = git remote | lines | each { |remote| git push --all $remote }
export alias gpgh = git push github
export alias gpo = git push -u origin
export alias gpod = git push -u origin dev
export alias gpom = git push -u origin main
export alias gprm = git push -u rpi main
export alias gpul = git pull origin main
export alias grar = git_remote_add_rpi
export alias grls = git_remote_ls_rpi
export alias grcr = git_remote_cr_rpi
export def grr [] {
    rm -rf .git
    git init
}
export alias grrc = git rm -r --cached .
export alias grv = git remote -v
export alias gs = git switch
export alias gsl = git switch -
export alias gsar = git_submodule_add_role
export alias gsc = git switch -c
export alias gscy = git_switch_create_ygt
export alias gscv = git_switch_create_variant
export alias gscw = git_switch_create_wip
export alias gmw = git merge --squash $"(git branch --show-current)--wip-palekiwi"
export alias gbd = git branch -d
export alias gbdw = git branch -d $"(git branch --show-current)--wip-palekiwi"
export alias gbDw = git branch -D $"(git branch --show-current)--wip-palekiwi"
export alias gbDrw = git push origin --delete $"(git branch --show-current)--wip-palekiwi"
export alias gsw = git_switch_wip
export alias gsv = git_switch_variant
export alias gbdv = git_branch_delete_variant
export alias gsd = git switch dev
export def gsm [] {
    git switch (get_master_branch_name)
    git pull
}
export def git_switch_integration_branch [] {
    let branch_name = $env | get -o SPABREAKS_INTEGRATION_BRANCH
    if ($branch_name | is-not-empty) {
        git switch $env.SPABREAKS_INTEGRATION_BRANCH
        git pull
    } else {
        print $"(ansi red) No integration branch set (ansi reset)"
        return 1
    }
}

export alias gsb = gs (get_pr_base)
export alias gsi = git_switch_integration_branch
export def gmb [] {
    set_pr_info
    git merge (get_pr_base) --no-edit
}
export alias gmv = git_merge_variant
export alias gsr = git_set_remote
export alias gst = git status
export alias gsts = git status --short
export alias gsur = git submodule update --remote
export def nah [] {
    git reset --hard
    git clean -dif
}
export alias gbn = git rev-parse --abbrev-ref HEAD
export alias gbnc = git_branch_name_to_clipboard
export alias gfm = git_fetch_master
export alias gfb = git_fetch_base
export def gub [] {
    set_pr_info
    git_fetch_base
    git merge (get_pr_base) --no-edit
}
