{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_status-repo" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="."
  fi

  if [ "$(git -C "$dir" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
      exit 0
  fi

  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)"
  if [ -z "$branch" ]; then
      branch="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
      if [ -z "$branch" ]; then
          exit 0
      fi
  fi

  behind_default=""
  base=""
  pr=""
  behind_base=""
  cue_context=""

  prefix="branch.$branch."
  while IFS=$'\n' read -r -d ''' key value; do
      case "$key" in
          "$prefix"behindDefault|"$prefix"behinddefault) behind_default="$value" ;;
          "$prefix"base) base="$value" ;;
          "$prefix"pr) pr="$value" ;;
          "$prefix"behindBase|"$prefix"behindbase) behind_base="$value" ;;
          "$prefix"cue-context) cue_context="$value" ;;
      esac
  done < <(git -C "$dir" config --local --null --get-regexp '^branch\..*\.(behindDefault|base|pr|behindBase|cue-context)$' 2>/dev/null)

  components=()
  if [ -n "$cue_context" ]; then
      components+=("#[fg=colour15,bold]$cue_context")
  fi

  if [ "$behind_default" = "true" ]; then
      components+=("#[fg=yellow,dim,bold]$branch")
  else
      components+=("#[fg=green]$branch")
  fi

  if [ -n "$base" ]; then
      if [ "$behind_base" = "true" ]; then
          base_color="yellow"
      else
          base_color="white"
      fi
      if [ -n "$pr" ]; then
          components+=("#[fg=green,dim,bold]#$pr #[fg=white,nobold,dim]-> #[fg=$base_color,bold]$base")
      else
          components+=("#[fg=white,nobold,dim]-> #[fg=$base_color,bold]$base")
      fi
  fi

  if [ ''${#components[@]} -gt 0 ]; then
      printf " %s" "''${components[*]}"
  fi
''
