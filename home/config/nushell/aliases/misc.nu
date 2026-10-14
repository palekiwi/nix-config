alias d = docker
alias dc = docker-compose
alias dcd = docker-compose down

def dps [] {
    docker ps --format '{{.Names}}\t{{.Status}}' | str trim
}

alias h = himalaya
alias hmd = himalaya message delete
alias hmr = himalaya message read

alias cr = cargo run

# exa listings (deliberately not shadowing the nushell `ls` builtin)
alias l = exa --group-directories-first
alias lll = exa -la --group-directories-first
alias llt = exa -l -T -L 2 --group-directories-first
alias lt = exa -T -L 2 --group-directories-first
alias ltt = exa -T -L 3 --group-directories-first
alias lttt = exa -T -L 4 --group-directories-first
