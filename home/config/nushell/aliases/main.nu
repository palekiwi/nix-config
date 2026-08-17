def cat_to_clipboard [input?: string] {
    if ($input != null) {
        bat -p ($input | path expand) | xclip -selection clipboard
    } else {
        $in | bat -p | xclip -selection clipboard
    }

}

def "gemini detach" [] {
    let session = $"(tmux display-message -p '#S')-gemini"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'gemini' C-m
    kitty --detach -T $session tmux attach -t $session
}

def "opencode detach" [] {
    let session = $"(tmux display-message -p '#S')-opencode"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'opencode-run' C-m
    kitty --detach -T $session tmux attach -t $session
}

def pass_insert [len: int, name: string] {
    pass generate -n $name $len | ignore
    pass edit $name
}

def ll [] {
    ls -la | select name type size mode user group created accessed modified | sort-by type
}

def direnv_rust [] {
    'use flake "github:palekiwi/flake-templates?dir=templates/rust/devshell"' | save .envrc
}

def revcom [
    pr_number?: int,
    --incremental (-i) # Only save comments added since previous review artifacts
] {
    let all_comments_json = (gh-utils review comments $pr_number --json)
    let all_comments = ($all_comments_json | from json)

    if ($all_comments | is-empty) {
        print "No review comments found on PR."
        return
    }

    if $incremental {
        let tmp_list = (do { cue list -t tmp --json } | complete)
        let files = if $tmp_list.exit_code == 0 and not ($tmp_list.stdout | is-empty) {
            try {
                $tmp_list.stdout
                | from json
                | where name == "review-comments.json" or ($it.path | str ends-with "review-comments.json")
            } catch {
                []
            }
        } else {
            []
        }

        let prev_ids = ($files | each {|f|
            if ($f.path | path exists) {
                try {
                    let content = (open $f.path)
                    if not ($content | is-empty) {
                        $content | get id
                    } else {
                        []
                    }
                } catch {
                    []
                }
            } else {
                []
            }
        } | flatten | uniq)

        if not ($prev_ids | is-empty) {
            let new_comments = ($all_comments | where {|c| $c.id not-in $prev_ids})
            if ($new_comments | is-empty) {
                print "No new review comments since last snapshot."
            } else {
                let count = ($new_comments | length)
                print $"Saving ($count) new review comment\(s\)..."
                $new_comments | to json | cue add --force -t tmp review-comments.json
            }
        } else {
            let count = ($all_comments | length)
            print $"No previous review artifacts found. Saving all ($count) comment\(s\)..."
            $all_comments_json | cue add --force -t tmp review-comments.json
        }
    } else {
        let count = ($all_comments | length)
        print $"Saving all ($count) review comment\(s\)..."
        $all_comments_json | cue add --force -t tmp review-comments.json
    }
}

alias cat = bat -p
alias ctc = cat_to_clipboard
alias ghrc = gh-utils repo clone
alias gu = gitui
alias hms = home-manager switch --flake $"($nu.home-dir)/nix-config/home#(whoami)@(hostname -s)"
alias o = opencode
alias orun = opencode-run
alias orunx = with-env { OPENCODE_WORKSPACE: "." } { opencode-run }
alias pc = pass -c
alias pgpom = pass git push origin master
alias pgpul = pass git pull origin master
alias pi = pass_insert
alias rebuild = sudo nixos-rebuild switch --flake $"($nu.home-dir)/nix-config#(hostname -s)"
alias rr = ranger
alias s. = sesh connect .
alias sg = ast-grep
alias t = ~/.nix-profile/bin/task
alias tt = taskwarrior-tui
alias v = nvim
alias xo = xdg-open
