#!/usr/bin/env zsh

source ~/.config/zsh/aliases.d/docker.zsh
source ~/.config/zsh/aliases.d/exa.zsh
source ~/.config/zsh/aliases.d/gh.zsh
source ~/.config/zsh/aliases.d/git.zsh
source ~/.config/zsh/aliases.d/himalaya.zsh
source ~/.config/zsh/aliases.d/rust.zsh
source ~/.config/zsh/aliases.d/ygt.zsh

alias cat="bat -p"
alias cdc="pwd | ctc"
alias chx="chmod +x"
alias ctc="cat_to_clipboard"
alias gu="gitui"
alias gud="gu ~/dotfiles"
alias gut="gu ~/tailnet"
alias ll="ls -la"
alias pc="pass -c"
alias rr="ranger"
alias update="home-manager switch --flake ~/nix-config/home#"$(whoami)@$(hostname -s)""
alias rebuild="sudo nixos-rebuild switch --flake ~/nix-config#$(hostname -s)"
alias v="nvim_fg"
alias xo="xdg-open"
alias orun="opencode-run"
alias gemini="gemini-cli"

alias s.="sesh connect ."

alias dotfiles="sesh connect dotfiles"

alias pgpa="pass git remote | xargs -L1 pass git push --all"
alias pgpom="cd ~/.password-store && git pull && git push"
alias pgpul="cd ~/.password-store && git pull"
alias pi="pass_insert"

pass_insert () {
    len=$1
    name=$2
    pass generate -n $name $len 1> /dev/null
    pass edit $name
}

nvim_fg () {
    if [ -z "$(jobs | grep nvim)" ]; then
        nvim $@
    else
        fg
    fi
}

cat_to_clipboard () {
    bat -p $1 | xclip -selection clipboard
}
