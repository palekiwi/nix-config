{ pkgs, ... }:

pkgs.writeShellScriptBin "sync_opencode_dotfiles" ''
  if [[ -n "$OPENCODE_SRC" && -d "$OPENCODE_SRC" && -n "$OPENCODE_DEST" ]]; then
      echo "Syncing opencode config..."
      mkdir -p .opencode
      rsync -av --delete "$OPENCODE_SRC/" "$OPENCODE_DEST/"
  elif [[ -n "$OPENCODE_SRC" ]]; then
      echo "Warning: Source directory '$OPENCODE_SRC' does not exist"
  fi
''
