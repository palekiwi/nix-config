{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_org" ''
  session="spabreaks/spabreaks-org"

  tmux new-window -t $session -n cast-mcp
  tmux send-keys -t $session:5 'cast mcp start' C-m
  tmux select-window -t $session:1
''
