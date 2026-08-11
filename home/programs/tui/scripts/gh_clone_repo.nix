{ pkgs, ... }:

pkgs.writeShellScriptBin "gh_clone_repo" ''
  # Option parsing
  SUBDIR=""
  INPUT=""

  while [ $# -gt 0 ]; do
      case "$1" in
          -s|--subdir)
              if [ -z "''${2:-}" ]; then
                  echo "Error: $1 requires an argument" >&2
                  exit 1
              fi
              SUBDIR="$2"
              shift 2
              ;;
          --subdir=*)
              SUBDIR="''${1#*=}"
              shift
              ;;
          -*)
              echo "Error: Unknown option: $1" >&2
              exit 1
              ;;
          *)
              if [ -n "$INPUT" ]; then
                  echo "Error: expected exactly one repository argument, got '$1'" >&2
                  exit 1
              fi
              INPUT="$1"
              shift
              ;;
      esac
  done

  # Check if a repository argument is provided
  if [ -z "$INPUT" ]; then
      echo "Usage: $0 [-s|--subdir <dir>] <author/repo>"
      echo "       $0 [-s|--subdir <dir>] <github-url>"
      echo ""
      echo "Options:"
      echo "  -s, --subdir <dir>   Group the repo under ~/code/<dir>/<author>/<repo>"
      echo ""
      echo "Examples:"
      echo "  $0 microsoft/vscode"
      echo "  $0 https://github.com/microsoft/vscode"
      echo "  $0 -s embedded raspberrypi/firmware"
      echo "  $0 --subdir=embedded raspberrypi/firmware"
      exit 1
  fi

  # Function to extract author/repo from different input formats
  extract_author_repo() {
      local input="$1"

      # If it's a full GitHub URL, extract author/repo
      if [[ "$input" =~ ^https?://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
          echo "''${BASH_REMATCH[1]}/''${BASH_REMATCH[2]}"
      # If it's already in author/repo format (allows hyphens, underscores, dots, etc.)
      elif [[ "$input" =~ ^[^/]+/[^/]+$ ]]; then
          echo "$input"
      else
          echo "Error: Invalid format. Expected 'author/repo' or 'https://github.com/author/repo'" >&2
          return 1
      fi
  }

  # Extract author/repo from input
  AUTHOR_REPO=$(extract_author_repo "$INPUT")
  if [ $? -ne 0 ]; then
      exit 1
  fi

  # Extract author and repo separately
  AUTHOR=$(echo "$AUTHOR_REPO" | cut -d'/' -f1)
  REPO=$(echo "$AUTHOR_REPO" | cut -d'/' -f2)

  # Define the base code directory
  CODE_DIR="$HOME/code"

  # Compute the target directory, optionally nested under a subdir grouping
  if [ -n "$SUBDIR" ]; then
      TARGET_DIR="$CODE_DIR/$SUBDIR/$AUTHOR/$REPO"
  else
      TARGET_DIR="$CODE_DIR/$AUTHOR/$REPO"
  fi

  # Create the parent directory tree if it doesn't exist
  mkdir -p "$(dirname "$TARGET_DIR")"

  # Clone the repository
  echo "Cloning $AUTHOR_REPO into $TARGET_DIR"

  if command -v gh &> /dev/null; then
      # Use gh cli if available
      gh repo clone "$AUTHOR_REPO" "$TARGET_DIR"
  else
      # Fall back to git clone
      git clone "https://github.com/$AUTHOR_REPO.git" "$TARGET_DIR"
  fi

  echo "Successfully cloned $AUTHOR_REPO into $TARGET_DIR"
''
