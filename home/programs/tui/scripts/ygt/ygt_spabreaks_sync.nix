{ pkgs, ... }:

pkgs.writeShellScriptBin "ygt_spabreaks_sync" ''
  set -euo pipefail
  
  if [ $# -ne 1 ]; then
    echo "Usage: ygt_spabreaks_sync <target_host>"
    echo "Example: ygt_spabreaks_sync prod"
    exit 1
  fi
  
  TARGET_HOST="$1"
  CODE_DIR="$HOME/code"
  PROJECT_DIR="ygt/spabreaks"
  PROJECT_PATH="$CODE_DIR/$PROJECT_DIR"

  # Files to sync
  FILES_TO_SYNC=(
    "config/secrets.yml"
    "config/cloudinary.yml"
  )

  echo "Syncing spabreaks config files from local to $TARGET_HOST..."
  
  # Check if project directory exists
  if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project directory $PROJECT_PATH does not exist"
    exit 1
  fi
  
  cd "$PROJECT_PATH"
  
  # Sync each file from local to target
  for file in "''${FILES_TO_SYNC[@]}"; do
    if [ ! -f "$file" ]; then
      echo "⚠ Warning: $file not found locally, skipping..."
      continue
    fi
    
    echo "Syncing $file..."
    rsync -avh "$file" "$TARGET_HOST:$CODE_DIR/$PROJECT_DIR/$file"
    echo "✓ Synced $file to $TARGET_HOST"
  done

  echo "Sync complete!"

''
