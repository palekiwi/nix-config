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

alias cat = bat -p
alias ctc = cat_to_clipboard
alias gu = gitui
alias hms = home-manager switch --flake $"($nu.home-path)/nix-config/home#(whoami)@(hostname -s)"
alias ll = ls -la
alias orun = opencode-run
alias orunx = with-env { OPENCODE_WORKSPACE: "." } { opencode-run }
alias pc = pass -c
alias pgpom = pass git push origin master
alias pgpul = pass git pull origin master
alias pi = pass_insert
alias rebuild = sudo nixos-rebuild switch --flake $"($nu.home-path)/nix-config#(hostname -s)"
alias rr = ranger
alias s. = sesh connect .
alias v = nvim
alias xo = xdg-open
