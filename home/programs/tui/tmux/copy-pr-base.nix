{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-pr-base" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="."
  fi

  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      tmux display-message "copy-pr-base: not a git repo: $dir"
      exit 0
  fi

  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  if [ -z "$branch" ]; then
      tmux display-message "copy-pr-base: detached HEAD (no branch): $dir"
      exit 0
  fi

  base="$(git -C "$dir" config "branch.$branch.base" 2>/dev/null)"
  if [ -z "$base" ]; then
      tmux display-message "copy-pr-base: no base branch configured for '$branch'"
      exit 0
  fi

  tmux set-buffer -w -- "$base"
  tmux display-message "copy-pr-base: copied '$base'"
''
