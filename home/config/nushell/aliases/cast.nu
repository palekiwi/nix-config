def "cdo" [] {
    let session = $"(tmux display-message -p '#S')-oc-cast"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'cast run opencode --hostname 0.0.0.0 --port 80' C-m
    kitty --detach -T $session tmux attach -t $session
}

def "cdp" [] {
    let session = $"(tmux display-message -p '#S')-pi-cast"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'cast run pi' C-m
    kitty --detach -T $session tmux attach -t $session
}
def ccs [] {
    cast config show | from json | transpose | explore
}

alias cca = cast config allow
alias ccd = cast config diff

alias cro = cast run opencode --hostname 0.0.0.0 --port 80
alias crp = cast run pi

alias cso = cast shell opencode
alias csp = cast shell pi
