{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_blog_dev" ''
  session="blog-dev"

  tmux rename-window -t $session:1 dev

  tmux send-keys -t $session:1 'make dev' C-m

  tmux select-window -t $session:1
''
