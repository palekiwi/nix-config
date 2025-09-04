{ pkgs, ... }:

pkgs.writeShellScriptBin "gh_clone_repo" ''
  # Check if argument is provided
  if [ $# -eq 0 ]; then
      echo "Usage: $0 <author/repo> or $0 <github-url>"
      echo "Examples:"
      echo "  $0 microsoft/vscode"
      echo "  $0 https://github.com/microsoft/vscode"
      exit 1
  fi

  INPUT="$1"

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

  # Create the code directory and author subdirectory if they don't exist
  mkdir -p "$CODE_DIR/$AUTHOR"

  # Clone the repository
  echo "Cloning $AUTHOR_REPO into $CODE_DIR/$AUTHOR/$REPO..."

  if command -v gh &> /dev/null; then
      # Use gh cli if available
      gh repo clone "$AUTHOR_REPO" "$CODE_DIR/$AUTHOR/$REPO"
  else
      # Fall back to git clone
      git clone "https://github.com/$AUTHOR_REPO.git" "$CODE_DIR/$AUTHOR/$REPO"
  fi

  echo "Successfully cloned $AUTHOR_REPO into $CODE_DIR/$AUTHOR/$REPO"
''
