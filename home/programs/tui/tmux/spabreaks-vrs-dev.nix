{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_vrs_dev" ''
  session="vrs-dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n vrs-db

  tmux send-keys -t $session:2 'docker-compose up db' C-m
  sleep 1
  tmux send-keys -t $session:1 'make dev' C-m

  tmux select-window -t $session:1
''
