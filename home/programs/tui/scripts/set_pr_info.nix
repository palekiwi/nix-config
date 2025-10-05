{ pkgs, ... }:

let
  orange = "\\033[33m";
  green = "\\033[32m";
  reset = "\\033[0m";
in
pkgs.writeShellScriptBin "set_pr_info" ''
  DEST_DIR=.git

  pr_info=$(${pkgs.gh}/bin/gh pr view --json number,baseRefName 2>/dev/null)

  if [ -n "$pr_info" ] && [ "$pr_info" != "null" ]; then
    GH_PR_NUMBER=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.number')
    GIT_BASE=$(echo "$pr_info" | ${pkgs.jq}/bin/jq -r '.baseRefName')

    echo "$GH_PR_NUMBER" > "$DEST_DIR/GH_PR_NUMBER"
    echo "$GIT_BASE" > "$DEST_DIR/GIT_BASE"

    # Check if base branch has new commits
    ${pkgs.git}/bin/git fetch origin "$GIT_BASE" --quiet

    # Get the merge base (common ancestor)
    merge_base=$(${pkgs.git}/bin/git merge-base HEAD origin/"$GIT_BASE")

    # Check if origin/base is ahead of the merge base
    if [ "$(${pkgs.git}/bin/git rev-parse origin/"$GIT_BASE")" != "$merge_base" ]; then
      echo "true" > "$DEST_DIR/GIT_BASE_AHEAD"
        echo -e "${orange}Base branch '$GIT_BASE' has new commits${reset}"
    fi

      echo -e "${green}Updated PR info: #$GH_PR_NUMBER (base: $GIT_BASE)${reset}"
  else
    rm -f .git/GH_PR_NUMBER .git/GIT_BASE .git/GIT_BASE_AHEAD
      echo -e "${green}Cleared PR info (not on a PR branch)${reset}"
  fi
''
