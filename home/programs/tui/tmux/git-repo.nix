{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_git-repo" ''
  #!/usr/bin/env bash

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Error: Not in a git repository"
      exit 1
  fi

  session=''${1:-$(tmux display-message -p '#S')}

  tmux rename-window -t $session:1 edit

  tmux new-window -t $session -n agent
  tmux new-window -t $session -n gitui
  tmux new-window -t $session -n run

  tmux send-keys -t $session:1 'nvim' C-m
  tmux send-keys -t $session:3 'gitui' C-m

  tmux select-window -t $session:3

  if [[ -n "$OPENCODE_WORKSPACE" ]]; then
      tmux send-keys -t $session:2 'opencode --port 80 --hostname 0.0.0.0' C-m
  fi
''