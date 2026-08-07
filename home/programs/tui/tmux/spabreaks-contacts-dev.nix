{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_contacts_dev" ''
  session="spabreaks/contacts/dev"

  tmux rename-window -t $session:1 dev

  tmux send-keys -t $session:1 'task dev:up' C-m

  tmux select-window -t $session:1
''
