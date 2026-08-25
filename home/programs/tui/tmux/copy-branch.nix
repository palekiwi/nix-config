{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-branch" ''
  dir="$1"
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  if [ -z "$branch" ]; then
      branch="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
  fi
  if [ -z "$branch" ]; then
      tmux display-message "copy-branch: not a git repo: $dir"
      exit 0
  fi
  tmux set-buffer -w -- "$branch"
  tmux display-message "copy-branch: copied '$branch'"
''
