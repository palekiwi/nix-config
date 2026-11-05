# cast DSL for the spike service-container model (pi-focused).
# Targets the container of the current directory; tmux session is `pi`.

# Start the container if needed, then attach or create the pi session.
def "cast pi" [] {
    cast up
    cast exec tmux new-session -A -s pi pi
}

def ccs [] {
    cast config show | from json | transpose | explore
}

alias cca = cast config allow
alias ccd = cast config diff
